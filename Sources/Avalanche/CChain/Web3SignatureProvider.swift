//
//  Web3SignatureProvider.swift
//  
//
//  Created by Ostap Danylovych on 21.01.2022.
//

import Foundation
#if !COCOAPODS
import web3swift
import BigInt
#endif

public struct Web3SignatureProvider: SignatureProvider {
    private let chainID: BigUInt
    private let signer: AvalancheSignatureProvider
    private let manager: AvalancheAddressManager
    
    public init(chainID: BigUInt, signer: AvalancheSignatureProvider, manager: AvalancheAddressManager) {
        self.chainID = chainID
        self.signer = signer
        self.manager = manager
    }
    
    private func _toExtended(address: EthereumAddress) throws -> EthAccount {
        try manager.extended(eth: [address]).first!
    }

    public func accounts(_ cb: @escaping SignatureProviderCallback<[EthereumAddress]>) {
        signer.accounts(type: .ethereumOnly) { res in
            cb(res.map { accounts in
                accounts.ethereum.map { $0.address }
            }.mapError(Web3Error.generalError))
        }
    }

    public func sign(transaction: EthereumTransaction,
                     with account: EthereumAddress,
                     using password: String,
                     _ cb: @escaping SignatureProviderCallback<EthereumTransaction>) {
        let extended: EthAccount
        do {
            extended = try _toExtended(address: account)
        } catch {
            cb(.failure(error))
            return
        }
        let transaction = ExtendedEthereumTransaction(
            transaction: transaction,
            account: extended,
            chainID: chainID
        )
        signer.sign(transaction: transaction) { res in
            cb(res.mapError(Web3Error.generalError))
        }
    }

    public func sign(message: Data,
                     with account: EthereumAddress,
                     using password: String,
                     _ cb: @escaping SignatureProviderCallback<Data>) {
        let extended: EthAccount
        do {
            extended = try _toExtended(address: account)
        } catch {
            cb(.failure(error))
            return
        }
        signer.sign(message: message, address: extended) { res in
            cb(res.map { $0.raw }.mapError(Web3Error.generalError))
        }
    }
}
