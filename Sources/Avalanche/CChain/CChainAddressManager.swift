//
//  CChainAddressManager.swift
//  
//
//  Created by Ostap Danylovych on 25.11.2021.
//

import Foundation
import web3swift

public struct AvalancheCChainApiAddressManager: AvalancheApiAddressManager {
    public typealias Acct = EthAccount
    
    public let manager: AvalancheAddressManager
    public let api: AvalancheCChainApi
    
    public init(manager: AvalancheAddressManager, api: AvalancheCChainApi) {
        self.manager = manager
        self.api = api
    }
    
    public func fetchedAccounts() -> [Acct] {
        manager.fetchedAccounts().ethereum
    }
    
    public func get(for account: Acct) throws -> Acct.Addr {
        try account.avalancheAddress(hrp: api.networkID.hrp, chainId: api.chainID.value)
    }
    
    public func accounts(result: @escaping (AvalancheSignatureProviderResult<[EthAccount]>) -> Void) {
        manager.accounts(type: .ethereumOnly) { res in
            switch res {
            case .success(let accounts):
                result(.success(accounts.ethereum))
            case .failure(let error):
                result(.failure(error))
            }
        }
    }
    
    public func extended(for addresses: [Acct.Addr]) throws -> [Acct.Addr.Extended] {
        let mapped = addresses.map { EthereumAddress($0.rawAddress, type: .normal)! }
        return try zip(addresses, manager.extended(eth: mapped)).map {
            try ExtendedAddress(address: $0.0, path: $0.1.path)
        }
    }
}
