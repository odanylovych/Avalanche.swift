//
//  AvaSigProvider.swift
//  
//
//  Created by Yehor Popovych on 26.08.2021.
//

import Foundation
#if !COCOAPODS
import Avalanche
#endif

private extension AvalancheBip44Keychain {
    private func signEthereumTx(
        tx: EthereumTransactionExt,
        _ cb: @escaping (AvalancheSignatureProviderResult<EthereumTransactionExt.Signed>) -> Void
    ) {
        let data = try! tx.serialized()
        let account = try! tx.signingAddresses()[0]
        guard let kp = _ethCache[account.accountIndex] else {
            return
        }
        guard let signature = kp.signEthereum(serialized: data) else {
            return
        }
        let signed = try! tx.toSigned(signatures: [account.address: signature])
        cb(.success(signed))
    }
    
    private func signAvaTx<T: ExtendedUnsignedTransaction>(
        tx: T,
        _ cb: @escaping (AvalancheSignatureProviderResult<T.Signed>) -> Void
    ) {
        let data = try! tx.serialized()
        let accounts = try! tx.signingAddresses()
        let keypairs: [(T.Addr, KeyPair)] = accounts.compactMap { address in
            try? _ethCache[address.accountIndex].map { kp in
                let derived = try kp
                    .derive(index: address.isChange ? 1 : 0, hard: false)
                    .derive(index: address.index, hard: false)
                return (address.address, derived)
            }
        }
        guard keypairs.count == accounts.count else {
            return
        }
        let signatures = keypairs.compactMap { (addr, kp) in
            kp.signAvalanche(serialized: data).map { (addr, $0) }
        }
        guard signatures.count == keypairs.count else {
            return
        }
        let signed = try! tx.toSigned(
            signatures: Dictionary(uniqueKeysWithValues: signatures)
        )
        cb(.success(signed))
    }
}

extension AvalancheBip44Keychain: AvalancheSignatureProvider {
    public func accounts(
        type: AvalancheSignatureProviderAccountRequestType,
        _ cb: @escaping (AvalancheSignatureProviderResult<AvalancheSignatureProviderAccounts>) -> Void
    ) {
        DispatchQueue.global().async {
            switch type {
            case .avalancheOnly:
                cb(.success((avalanche: self.avalancheAccounts(), ethereum: [])))
            case .ethereumOnly:
                cb(.success((avalanche: [], ethereum: self.ethereumAccounts())))
            case .both:
                cb(.success((avalanche: self.avalancheAccounts(), ethereum: self.ethereumAccounts())))
            }
        }
    }
    
    public func sign<T>(
        transaction: T,
        _ cb: @escaping (AvalancheSignatureProviderResult<T.Signed>) -> Void
    ) where T : ExtendedUnsignedTransaction {
        DispatchQueue.global().async {
            if let transaction = transaction as? EthereumTransactionExt {
                self.signEthereumTx(tx: transaction) { res in
                    cb(res.map { $0 as! T.Signed })
                }
            } else {
                self.signAvaTx(tx: transaction, cb)
            }
        }
    }
    
    public func sign(
        ethereum message: Data,
        account: EthAccount,
        _ cb: @escaping (AvalancheSignatureProviderResult<Signature>) -> Void
    ) {
        DispatchQueue.global().async {
            guard let kp = self._ethCache[account.accountIndex] else {
                return
            }
            guard let signature = kp.signEthereum(message: message) else {
                return
            }
            cb(.success(signature))
        }
    }
}
