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
    private func signTx<T: ExtendedUnsignedTransaction>(
        tx: T,
        isEthereum: Bool,
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
            if isEthereum {
                guard let kp = _ethCache[address.accountIndex] else {
                    cb(.failure(.accountNotFound(account: address.path.account!)))
                    return
                }
                keypairs.append((address, kp))
            } else {
                guard let kp = _avaCache[address.accountIndex] else {
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
        }
        var signatures: Dictionary<T.Addr, Signature> = [:]
        signatures.reserveCapacity(addresses.count)
        for (addr, kp) in keypairs {
            let sign = isEthereum
                ? kp.signEthereum(serialized: data)
                : kp.signAvalanche(serialized: data)
            guard let sig = sign else {
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
            self.signTx(tx: transaction,
                        isEthereum: transaction is EthereumTransactionExt,
                        cb)
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
