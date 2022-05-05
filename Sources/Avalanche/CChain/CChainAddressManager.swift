//
//  CChainAddressManager.swift
//  
//
//  Created by Ostap Danylovych on 25.11.2021.
//

import Foundation

public class AvalancheCChainAddressManager {
    public typealias Acct = EthAccount
    
    private let queue: DispatchQueue
    public let manager: AvalancheAddressManager
    private var extended: [Acct.Addr: Acct.Addr.Extended]
    
    public init(manager: AvalancheAddressManager) {
        self.manager = manager
        self.extended = [:]
        self.queue = DispatchQueue(
            label: "cchain.address.manager.internal.sync.queue",
            target: .global()
        )
    }
    
    public func get(api: AvalancheCChainApi, for account: Acct) throws -> Acct.Addr {
        try account.avalancheAddress(hrp: api.networkID.hrp, chainId: api.chainID.value)
    }
    
    public func accounts(api: AvalancheCChainApi,
                         result: @escaping (AvalancheSignatureProviderResult<[Acct]>) -> Void) {
        manager.accounts(type: .ethereumOnly) { res in
            switch res {
            case .success(let accounts):
                let accounts = accounts.ethereum
                let extended: [Acct.Addr: Acct.Addr.Extended]
                do {
                    extended = try Dictionary(uniqueKeysWithValues: accounts.map {
                        let address = try self.get(api: api, for: $0)
                        return (address, try address.extended(path: $0.path))
                    })
                } catch {
                    result(.failure(.addressCreationFailed(error: error)))
                    return
                }
                self.queue.sync {
                    self.extended = extended
                }
                result(.success(accounts))
            case .failure(let error):
                result(.failure(error))
            }
        }
    }
    
    public func extended(for addresses: [Acct.Addr]) throws -> [Acct.Addr.Extended] {
        try addresses.map { address in
            try queue.sync {
                guard let extended = extended[address] else {
                    throw AvalancheAddressManagerError.addressNotFound(address: address.bech)
                }
                return extended
            }
        }
    }
}

public struct AvalancheCChainApiAddressManager: AvalancheApiAddressManager {
    public typealias Acct = EthAccount
    
    public let manager: AvalancheCChainAddressManager
    public let api: AvalancheCChainApi
    
    public init(manager: AvalancheCChainAddressManager, api: AvalancheCChainApi) {
        self.manager = manager
        self.api = api
    }
    
    public func get(for account: Acct) throws -> Acct.Addr {
        try manager.get(api: api, for: account)
    }
    
    public func accounts(result: @escaping (AvalancheSignatureProviderResult<[EthAccount]>) -> Void) {
        manager.accounts(api: api, result: result)
    }
    
    public func extended(for addresses: [Address]) throws -> [ExtendedAddress] {
        try manager.extended(for: addresses)
    }
}
