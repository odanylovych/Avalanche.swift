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
            switch deriveKeyPair(for: address.path) {
            case .failure(let err):
                cb(.failure(err))
                return
            case .success(let kp):
                keypairs.append((address, kp))
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
    
    private func deriveKeyPair(for path: Bip32Path) -> AvalancheSignatureProviderResult<KeyPair> {
        if path.isValidEthereumAccount {
            guard let kp = _ethCache[path.accountIndex!] else {
                return .failure(.accountNotFound(account: path.account!))
            }
            return .success(kp)
        } else {
            guard let kp = _avaCache[path.accountIndex!] else {
                return .failure(.accountNotFound(account: path.account!))
            }
            let derived = try? kp
                .derive(index: path.isChange! ? 1 : 0, hard: false)
                .derive(index: path.addressIndex!, hard: false)
            guard let der = derived else {
                return .failure(.derivationFailed(address: path))
            }
            return .success(der)
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
                        isEthereum: transaction is ExtendedEthereumTransaction,
                        cb)
        }
    }
    
    public func sign<A: ExtendedAddressProtocol>(
        message: Data,
        address: A,
        _ cb: @escaping (AvalancheSignatureProviderResult<Signature>) -> Void) {
        DispatchQueue.global().async {
            let isEthereum = address is EthAccount
            switch self.deriveKeyPair(for: address.path) {
            case .failure(let err):
                cb(.failure(err))
            case .success(let kp):
                let sig = isEthereum
                    ? kp.signEthereum(message: message)
                    : kp.signAvalanche(message: message)
                guard let signature = sig else {
                    cb(.failure(.signingFailed(address: address.path, reason: "")))
                    return
                }
                cb(.success(signature))
            }
        }
    }
}
