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
  
    public func accounts(
        result: @escaping (AvalancheSignatureProviderResult<[Acct]>) -> Void
    ) {
        accounts(forceUpdate: false, result: result)
    }
    
    public func accounts(
        forceUpdate: Bool,
        result: @escaping (AvalancheSignatureProviderResult<[Acct]>) -> Void
    ) {
        manager.accounts(type: .avalancheOnly, forceUpdate: forceUpdate) {
            result($0.map { $0.avalanche })
        }
    }
    
    public func extended(for addresses: [Acct.Addr]) throws -> [Acct.Addr.Extended] {
        try manager.extended(avm: addresses)
    }
    
    public func addresses(for account: Acct, change: Bool) -> [Acct.Addr] {
        manager.addresses(avm: api,
                          account: account,
                          change: change)
    }
    
    public func newAddresses(for account: Acct,
                             change: Bool,
                             count: Int) -> [Acct.Addr] {
        manager.newAddresses(avm: api,
                             account: account,
                             change: change,
                             count: count)
    }
    
    public func fetchAddresses(
        for account: Acct, change: Bool,
        result: ApiCallback<[Acct.Addr]>?
    ) {
        manager.fetchAddresses(avm: api, account: account, change: change) { res in
            result?(res.map { self.addresses(for: account, change: change) })
        }
    }
}
