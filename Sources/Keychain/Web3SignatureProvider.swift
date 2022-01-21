//
//  Web3SignatureProvider.swift
//  
//
//  Created by Ostap Danylovych on 21.01.2022.
//

import Foundation
#if !COCOAPODS
import Avalanche
import web3swift
#endif

extension EthereumAddress {
    public init(from address: EthAddress) {
        self.init(address.rawAddress)!
    }
}

extension EthAddress {
    public init(from address: EthereumAddress) {
        try! self.init(pubKey: address.addressData)
    }
}

extension AvalancheBip44Keychain: SignatureProvider {
    private func _getPrivateKey(for account: EthereumAddress) throws -> Data {
        guard let account = ethereumAccounts().first(where: { $0.address == EthAddress(from: account) }),
              let keyPair = _ethCache[account.index] else {
            throw Web3Error.inputError(desc: "No such account in keychain: \(account)")
        }
        return keyPair.privateData
    }

    public func accounts(_ cb: @escaping SignatureProviderCallback<[EthereumAddress]>) {
        accounts(type: .ethereumOnly) { res in
            cb(res.map { accounts in
                accounts.ethereum.map { EthereumAddress(from: $0.address) }
            }.mapError(Web3Error.generalError))
        }
    }

    public func sign(transaction: EthereumTransaction,
                     with account: EthereumAddress,
                     using password: String,
                     _ cb: @escaping SignatureProviderCallback<EthereumTransaction>) {
        var transaction = transaction
        do {
            try Web3Signer.signTX(transaction: &transaction, privateKey: try _getPrivateKey(for: account))
        } catch {
            cb(.failure(error))
        }
        cb(.success(transaction))
    }

    public func sign(message: Data,
                     with account: EthereumAddress,
                     using password: String,
                     _ cb: @escaping SignatureProviderCallback<Data>) {
        cb(Result {
            guard let data = try Web3Signer.signPersonalMessage(message, privateKey: try _getPrivateKey(for: account)) else {
                throw Web3Error.processingError(
                    desc: "Cannot sign a message. Message: \(String(describing: message)). Account: \(String(describing: account))"
                )
            }
            return data
        })
    }
}
