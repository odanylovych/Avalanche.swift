//
//  TransactionApiSupport.swift
//  
//
//  Created by Ostap Danylovych on 10.02.2022.
//

import Foundation

public protocol TransactionApiSupport {
    associatedtype AddressManager: AvalancheApiUTXOAddressManager where AddressManager.Acct == Account
    
    var queue: DispatchQueue { get }
    var keychain: AddressManager? { get }
    var signer: AvalancheSignatureProvider? { get }
    var encoderDecoderProvider: AvalancheEncoderDecoderProvider { get }
    
    func issueTx(tx: String,
                 encoding: AvalancheEncoding?,
                 _ cb: @escaping ApiCallback<TransactionID>)
}

extension TransactionApiSupport {
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
                                with addresses: [Address],
                                using utxos: [UTXO],
                                _ cb: @escaping ApiCallback<SignedAvalancheTransaction>) {
        guard let keychain = keychain else {
            handleError(.nilAddressManager, cb)
            return
        }
        guard let signer = signer else {
            handleError(.nilSignatureProvider, cb)
            return
        }
        let extendedAddresses: [Address: Address.Extended]
        do {
            extendedAddresses = Dictionary(
                uniqueKeysWithValues: try keychain.extended(for: addresses).map { ($0.address, $0) }
            )
        } catch {
            handleError(error, cb)
            return
        }
        let extendedTransaction: ExtendedAvalancheTransaction
        do {
            extendedTransaction = try ExtendedAvalancheTransaction(
                transaction: transaction,
                utxos: utxos,
                extended: extendedAddresses
            )
        } catch {
            handleError(error, cb)
            return
        }
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
                            with addresses: [Address],
                            using utxos: [UTXO],
                            _ cb: @escaping ApiCallback<TransactionID>) {
        signTransaction(transaction, with: addresses, using: utxos) { res in
            switch res {
            case .success(let signed): issueTransaction(signed, cb)
            case .failure(let error): handleError(error, cb)
            }
        }
    }
}
