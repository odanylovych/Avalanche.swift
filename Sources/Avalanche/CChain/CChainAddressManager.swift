//
//  CChainAddressManager.swift
//  
//
//  Created by Ostap Danylovych on 25.11.2021.
//

import Foundation

public struct AvalancheCChainApiAddressManager: AvalancheApiAddressManager {
    public typealias Acct = EthAccount
    
    public let manager: AvalancheAddressManager
    public let api: AvalancheCChainApi
    
    public init(manager: AvalancheAddressManager, api: AvalancheCChainApi) {
        self.manager = manager
        self.api = api
    }
    
    public func accounts(result: @escaping (AvalancheSignatureProviderResult<[Acct]>) -> Void) {
        manager.accounts(type: .ethereumOnly) {
            result($0.map { $0.ethereum })
        }
    }
    
    public func extended(for addresses: [Acct.Addr]) throws -> [Acct.Addr.Extended] {
        try manager.extended(eth: addresses)
    }
}
