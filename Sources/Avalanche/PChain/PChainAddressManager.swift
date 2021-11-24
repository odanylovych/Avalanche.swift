//
//  PChainAddressManager.swift
//  
//
//  Created by Yehor Popovych on 01.09.2021.
//

import Foundation

public struct AvalanchePChainApiAddressManager: AvalancheApiUTXOAddressManager {
    public typealias Acct = Account
    
    public let manager: AvalancheAddressManager
    public let api: AvalanchePChainApi
    
    public init(manager: AvalancheAddressManager, api: AvalanchePChainApi) {
        self.manager = manager
        self.api = api
    }
    
    public func accounts(result: @escaping (AvalancheSignatureProviderResult<[Acct]>) -> Void) {
        manager.accounts(type: .avalancheOnly) {
            result($0.map { $0.avalanche })
        }
    }
    
    public func extended(for addresses: [Acct.Addr]) throws -> [Acct.Addr.Extended] {
        try manager.extended(avm: addresses)
    }
    
    public func new(for account: Acct, change: Bool, count: Int) throws -> [Acct.Addr] {
        try manager.new(avm: api, for: account, change: change, count: count)
    }
    
    public func get(cached account: Acct) throws -> [Acct.Addr] {
        try manager.get(avm: api, cached: account)
    }
    
    public func get(for account: Acct, _ cb: @escaping (Result<[Acct.Addr], Error>) -> Void) {
        manager.get(avm: api, for: account, cb)
    }
    
    public func fetch(for accounts: [Acct], _ cb: @escaping (Result<Void, Error>) -> Void) {
        manager.fetch(avm: api, for: accounts, cb)
    }
    
    public func fetch(_ cb: @escaping (Result<Void, Error>) -> Void) {
        manager.fetch(avm: api, cb)
    }
    
    public func fetchedAccounts() -> [Acct] {
        manager.fetchedAccounts().avalanche
    }
}
