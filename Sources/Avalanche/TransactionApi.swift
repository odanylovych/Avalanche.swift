//
//  TransactionApi.swift
//  
//
//  Created by Ostap Danylovych on 10.02.2022.
//

import Foundation

public protocol AvalancheTransactionApi: AvalancheVMApi {
    associatedtype AddressManager: AvalancheApiAddressManager where AddressManager.Acct.Addr == Address
    
    var queue: DispatchQueue { get }
    var keychain: AddressManager? { get }
    var utxoProvider: AvalancheUtxoProvider { get }
    var signer: AvalancheSignatureProvider? { get }
    var encoderDecoderProvider: AvalancheEncoderDecoderProvider { get }
    
    func getBlockchainID(_ cb: @escaping ApiCallback<BlockchainID>)
    func getAvaxAssetID(_ cb: @escaping ApiCallback<AssetID>)
    func issueTx(tx: String,
                 encoding: AvalancheEncoding?,
                 _ cb: @escaping ApiCallback<TransactionID>)
}

extension AvalancheTransactionApi {
    func handleError<R: Any>(_ error: AvalancheApiError, _ cb: @escaping ApiCallback<R>) {
        queue.async {
            cb(.failure(error))
        }
    }
    
    func handleError<R: Any>(_ error: Error, _ cb: @escaping ApiCallback<R>) {
        queue.async {
            cb(.failure(.custom(cause: error)))
        }
    }
    
    public func signTransaction(_ transaction: UnsignedAvalancheTransaction,
                                _ cb: @escaping ApiCallback<SignedAvalancheTransaction>) {
        signTransaction(transaction, source: self, cb)
    }
    
    public func signTransaction<A: AvalancheVMApi>(_ transaction: UnsignedAvalancheTransaction,
                                                   source api: A,
                                                   _ cb: @escaping ApiCallback<SignedAvalancheTransaction>) {
        guard let keychain = keychain else {
            handleError(.nilAddressManager, cb)
            return
        }
        guard let signer = signer else {
            handleError(.nilSignatureProvider, cb)
            return
        }
        let inputsData = transaction.inputsData
        utxoProvider.utxos(api: api, ids: inputsData.map { ($0.transactionID, $0.utxoIndex) }) { res in
            switch res {
            case .success(let utxos):
                let credentialAddresses = inputsData.map { inputData -> (Credential.Type, [Address]) in
                    let utxo = utxos.first(where: {
                        $0.transactionID == inputData.transactionID
                        && $0.utxoIndex == inputData.utxoIndex
                    })!
                    return (
                        inputData.credentialType,
                        inputData.addressIndices.map {
                            let address = utxo.output.addresses[Int($0)]
                            return try! Address(raw: address.rawAddress, hrp: address.hrp, chainId: self.chainID.value)
                        }
                    )
                }
                let extendedAddresses: [Address: Address.Extended]
                do {
                    let addresses = Set(credentialAddresses.flatMap { $0.1 })
                    extendedAddresses = Dictionary(
                        uniqueKeysWithValues: try keychain.extended(for: Array(addresses)).map {
                            ($0.address, $0)
                        }
                    )
                } catch {
                    handleError(error, cb)
                    return
                }
                let extendedTransaction = ExtendedAvalancheTransaction(
                    transaction: transaction,
                    credential: credentialAddresses,
                    extended: extendedAddresses
                )
                signer.sign(transaction: extendedTransaction) { res in
                    switch res {
                    case .success(let signed):
                        queue.async {
                            cb(.success(signed))
                        }
                    case .failure(let error):
                        handleError(error, cb)
                    }
                }
            case .failure(let error):
                handleError(error, cb)
            }
        }
    }
    
    public func issueTransaction(_ transaction: SignedAvalancheTransaction,
                                 _ cb: @escaping ApiCallback<TransactionID>) {
        let encoded: String
        do {
            encoded = try encoderDecoderProvider.encoder().encode(transaction).output.cb58()
        } catch {
            handleError(error, cb)
            return
        }
        issueTx(tx: encoded, encoding: .cb58) { res in
            queue.async {
                cb(res)
            }
        }
    }
    
    public func signAndSend(_ transaction: UnsignedAvalancheTransaction,
                            _ cb: @escaping ApiCallback<TransactionID>) {
        signAndSend(transaction, source: self, cb)
    }
    
    public func signAndSend<A: AvalancheVMApi>(_ transaction: UnsignedAvalancheTransaction,
                                               source api: A,
                                               _ cb: @escaping ApiCallback<TransactionID>) {
        signTransaction(transaction, source: api) { res in
            switch res {
            case .success(let signed): issueTransaction(signed, cb)
            case .failure(let error): handleError(error, cb)
            }
        }
    }
}

extension AvalancheTransactionApi where AddressManager: AvalancheApiUTXOAddressManager,
                                        AddressManager.Acct == Account  {
    func withTransactionData(for account: Account,
                             from: [Address]? = nil,
                             change: Address? = nil,
                             sourceChain: BlockchainID? = nil,
                             _ cb: @escaping ApiCallback<([UTXO], [Address], Address, AssetID, BlockchainID)>) {
        guard let keychain = keychain else {
            handleError(.nilAddressManager, cb)
            return
        }
        let fromAddresses: [Address]
        do {
            fromAddresses = try from ?? keychain.get(cached: account)
        } catch {
            handleError(error, cb)
            return
        }
        let utxoIterator = utxoProvider.utxos(api: self, addresses: fromAddresses)
        UTXOHelper.getAll(iterator: utxoIterator, sourceChain: sourceChain) { res in
            switch res {
            case .success(let utxos):
                getBlockchainID { res in
                    switch res {
                    case .success(let blockchainID):
                        getAvaxAssetID { res in
                            switch res {
                            case .success(let avaxAssetID):
                                let changeAddress: Address
                                do {
                                    changeAddress = try change ?? keychain.newChange(for: account)
                                } catch {
                                    handleError(error, cb)
                                    return
                                }
                                cb(.success((utxos, fromAddresses, changeAddress, avaxAssetID, blockchainID)))
                            case .failure(let error):
                                handleError(error, cb)
                            }
                        }
                    case .failure(let error):
                        handleError(error, cb)
                    }
                }
            case .failure(let error):
                handleError(error, cb)
            }
        }
    }
}
