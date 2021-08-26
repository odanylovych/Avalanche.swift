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
        let data: Data
        do {
            data = try tx.serialized()
        } catch let error {
            cb(.failure(.serializationFailed(error: error)))
            return
        }
        let accounts: [EthereumTransactionExt.Addr.Extended]
        do {
            accounts = try tx.signingAddresses()
        } catch let error {
            cb(.failure(.signingAddressesListFailed(error: error)))
            return
        }
        guard accounts.count > 0 else {
            cb(.failure(.signingAddressesListIsEmpty))
            return
        }
        let account = accounts[0]
        guard let kp = _ethCache[account.accountIndex] else {
            cb(.failure(.accountNotFound(account: account.path)))
            return
        }
        guard let signature = kp.signEthereum(serialized: data) else {
            cb(.failure(.signingFailed(address: account.path, reason: "")))
            return
        }
        do {
            let signed = try tx.toSigned(signatures: [account.address: signature])
            cb(.success(signed))
        } catch let error {
            cb(.failure(.signedTransactionInitFailed(error: error)))
        }
    }
    
    private func signAvaTx<T: ExtendedUnsignedTransaction>(
        tx: T,
        _ cb: @escaping (AvalancheSignatureProviderResult<T.Signed>) -> Void
    ) {
        let data: Data
        do {
            data = try tx.serialized()
        } catch let error {
            cb(.failure(.serializationFailed(error: error)))
            return
        }
        let addresses: [T.Addr.Extended]
        do {
            addresses = try tx.signingAddresses()
        } catch let error {
            cb(.failure(.signingAddressesListFailed(error: error)))
            return
        }
        guard addresses.count > 0 else {
            cb(.failure(.signingAddressesListIsEmpty))
            return
        }
        var keypairs: [(T.Addr.Extended, KeyPair)] = []
        keypairs.reserveCapacity(addresses.count)
        for address in addresses {
            guard let kp = _ethCache[address.accountIndex] else {
                cb(.failure(.accountNotFound(account: address.path.account!)))
                return
            }
            let derived = try? kp
                .derive(index: address.isChange ? 1 : 0, hard: false)
                .derive(index: address.index, hard: false)
            guard let der = derived else {
                cb(.failure(.derivationFailed(address: address.path)))
                return
            }
            keypairs.append((address, der))
        }
        var signatures: Dictionary<T.Addr, Signature> = [:]
        signatures.reserveCapacity(addresses.count)
        for (addr, kp) in keypairs {
            guard let sig = kp.signAvalanche(serialized: data) else {
                cb(.failure(.signingFailed(address: addr.path, reason: "")))
                return
            }
            signatures[addr.address] = sig
        }
        do {
            let signed = try tx.toSigned(signatures: signatures)
            cb(.success(signed))
        } catch let error {
            cb(.failure(.signedTransactionInitFailed(error: error)))
        }
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
