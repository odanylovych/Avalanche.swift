//
//  CChain+Transactions.swift
//  
//
//  Created by Ostap Danylovych on 10.02.2022.
//

import Foundation
#if !COCOAPODS
import web3swift
#endif

extension AvalancheCChainApi {
    public func txExport(
        to: Address,
        amount: UInt64,
        assetID: AssetID,
        baseFee: UInt64? = nil,
        account: EthAccount,
        _ cb: @escaping ApiCallback<TransactionID>
    ) {
        getAvaxAssetID { res in
            switch res {
            case .success(let avaxAssetID):
                self.getBlockchainID { res in
                    switch res {
                    case .success(let blockchainID):
                        self.getTxFee { res in
                            switch res {
                            case .success(let txFee):
                                self.blockchainIDs(ChainID(to.chainId)) { res in
                                    switch res {
                                    case .success(let destinationChain):
                                        let fee = baseFee ?? txFee
                                        let address = account.address
                                        self.getTransactionCount(for: address) { res in
                                            switch res {
                                            case .success(let nonce):
                                                var inputs = [EVMInput]()
                                                if assetID == avaxAssetID {
                                                    inputs.append(EVMInput(
                                                        address: address,
                                                        amount: amount + fee,
                                                        assetID: assetID,
                                                        nonce: nonce
                                                    ))
                                                } else {
                                                    inputs.append(contentsOf: [
                                                        EVMInput(
                                                            address: address,
                                                            amount: fee,
                                                            assetID: avaxAssetID,
                                                            nonce: nonce
                                                        ),
                                                        EVMInput(
                                                            address: address,
                                                            amount: amount,
                                                            assetID: assetID,
                                                            nonce: nonce
                                                        )
                                                    ])
                                                }
                                                let exportedOutputs: [TransferableOutput]
                                                do {
                                                    exportedOutputs = [
                                                        TransferableOutput(
                                                            assetID: assetID,
                                                            output: try SECP256K1TransferOutput(
                                                                amount: amount,
                                                                locktime: Date(timeIntervalSince1970: 0),
                                                                threshold: 1,
                                                                addresses: [to]
                                                            )
                                                        )
                                                    ]
                                                } catch {
                                                    self.handleError(error, cb)
                                                    return
                                                }
                                                let transaction = CChainExportTransaction(
                                                    networkID: self.networkID,
                                                    blockchainID: blockchainID,
                                                    destinationChain: destinationChain,
                                                    inputs: inputs,
                                                    exportedOutputs: exportedOutputs
                                                )
                                                self.signAndSend(transaction, cb)
                                            case .failure(let error):
                                                self.handleError(error, cb)
                                            }
                                        }
                                    case .failure(let error):
                                        self.handleError(error, cb)
                                    }
                                }
                            case .failure(let error):
                                self.handleError(error, cb)
                            }
                        }
                    case .failure(let error):
                        self.handleError(error, cb)
                    }
                }
            case .failure(let error):
                self.handleError(error, cb)
            }
        }
    }
    
    public func txImport(
        to: EthereumAddress,
        sourceChain: BlockchainID,
        baseFee: UInt64? = nil,
        account: EthAccount,
        _ cb: @escaping ApiCallback<TransactionID>
    ) {
        guard let keychain = keychain else {
            handleError(.nilAddressManager, cb)
            return
        }
        let address: Address
        do {
            address = try keychain.get(for: account)
        } catch {
            self.handleError(error, cb)
            return
        }
        let utxoIterator = self.utxoProvider.utxos(api: self, addresses: [address])
        UTXOHelper.getAll(iterator: utxoIterator, sourceChain: sourceChain) { res in
            switch res {
            case .success(let utxos):
                self.getBlockchainID { res in
                    switch res {
                    case .success(let blockchainID):
                        self.getAvaxAssetID { res in
                            switch res {
                            case .success(let avaxAssetID):
                                self.getTxFee { res in
                                    switch res {
                                    case .success(let txFee):
                                        let feeAssetID = avaxAssetID
                                        let fee = baseFee ?? txFee
                                        var feePaid: UInt64 = 0
                                        var importedInputs = [TransferableInput]()
                                        var assetIDAmount = [AssetID: UInt64]()
                                        for utxo in utxos.filter({ type(of: $0.output) == SECP256K1TransferOutput.self }) {
                                            let output = utxo.output as! SECP256K1TransferOutput
                                            var inFeeAmount = output.amount
                                            if fee > 0 && feePaid < fee && utxo.assetID == feeAssetID {
                                                feePaid += inFeeAmount
                                                if feePaid > fee {
                                                    inFeeAmount = feePaid - fee
                                                    feePaid = fee
                                                } else {
                                                    inFeeAmount = 0
                                                }
                                            }
                                            let input: TransferableInput
                                            do {
                                                input = TransferableInput(
                                                    transactionID: utxo.transactionID,
                                                    utxoIndex: utxo.utxoIndex,
                                                    assetID: utxo.assetID,
                                                    input: try SECP256K1TransferInput(
                                                        amount: output.amount,
                                                        addressIndices: output.getAddressIndices(for: output.addresses)
                                                    )
                                                )
                                            } catch {
                                                self.handleError(error, cb)
                                                return
                                            }
                                            importedInputs.append(input)
                                            if let amount = assetIDAmount[utxo.assetID] {
                                                inFeeAmount += amount
                                            }
                                            assetIDAmount[utxo.assetID] = inFeeAmount
                                        }
                                        var outputs = [EVMOutput]()
                                        for (assetID, amount) in assetIDAmount {
                                            outputs.append(EVMOutput(
                                                address: to,
                                                amount: amount,
                                                assetID: assetID
                                            ))
                                        }
                                        let transaction = CChainImportTransaction(
                                            networkID: self.networkID,
                                            blockchainID: blockchainID,
                                            sourceChain: sourceChain,
                                            importedInputs: importedInputs,
                                            outputs: outputs
                                        )
                                        self.signAndSend(transaction, cb)
                                    case .failure(let error):
                                        self.handleError(error, cb)
                                    }
                                }
                            case .failure(let error):
                                self.handleError(error, cb)
                            }
                        }
                    case .failure(let error):
                        self.handleError(error, cb)
                    }
                }
            case .failure(let error):
                self.handleError(error, cb)
            }
        }
    }
}
