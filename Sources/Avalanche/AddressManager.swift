//
//  AddressManager.swift
//  
//
//  Created by Yehor Popovych on 01.09.2021.
//

import Foundation

public enum AvalancheAddressManagerError: Error {
    case addressNotFound(address: String)
}

public typealias AddressUsedFilterCallback<A: AddressProtocol> =
    ([A], @escaping ApiCallback<[A]>) -> Void

public protocol AvalancheAddressManager: AnyObject {
    func accounts(
        type: AvalancheSignatureProviderAccountRequestType,
        forceUpdate: Bool,
        _ cb: @escaping (AvalancheSignatureProviderResult<AvalancheSignatureProviderAccounts>) -> Void
    )
    
    func addresses(avm account: Account,
                   chainId: String, hrp: String,
                   change: Bool) -> [Address]
    
    func newAddresses(avm account: Account,
                      chainId: String, hrp: String,
                      change: Bool, count: Int) -> [Address]
    
    func extended(avm addresses: [Address]) throws -> [ExtendedAddress]
    func extended(eth addresses: [EthAddress]) throws -> [EthAccount]
    
    func fetchMoreAddresses(avm account: Account,
                            chainId: String, hrp: String, change: Bool,
                            filter: @escaping AddressUsedFilterCallback<Address>)
}

public class AvalancheDefaultAddressManager: AvalancheAddressManager {
    public let signer: AvalancheSignatureProvider
    public let queue: DispatchQueue
    
    private var accountsCache: AvalancheSignatureProviderAccounts?
    private var syncQueue: DispatchQueue
    private var addresses: Dictionary<Account, Dictionary<Address, Bip32Path>>
    
    public init(signer: AvalancheSignatureProvider, queue: DispatchQueue) {
        self.signer = signer
        self.accountsCache = nil
        self.queue = .global()
        self.syncQueue = DispatchQueue(
            label: "address.manager.internal.sync.queue",
            qos: .userInitiated,
            target: .global(qos: .userInitiated)
        )
        self.addresses = [:]
    }
    
    public func accounts(
        type: AvalancheSignatureProviderAccountRequestType,
        forceUpdate: Bool = false,
        _ cb: @escaping (AvalancheSignatureProviderResult<AvalancheSignatureProviderAccounts>) -> Void
    ) {
        let returnAccounts = { (accounts: AvalancheSignatureProviderAccounts) in
            self.queue.async {
                switch type {
                case .avalancheOnly:
                    cb(.success((avalanche: accounts.avalanche, ethereum: [])))
                case .ethereumOnly:
                    cb(.success((avalanche: [], ethereum: accounts.ethereum)))
                case .both:
                    cb(.success(accounts))
                }
            }
        }
        let cached = self.syncQueue.sync { self.accountsCache }
        guard let accounts = cached, !forceUpdate else {
            signer.accounts(type: .both) { res in
                switch res {
                case .success(let accounts):
                    self.syncQueue.sync {
                        self.accountsCache = accounts
                    }
                    returnAccounts(accounts)
                case .failure(let err):
                    self.queue.async { cb(.failure(err)) }
                }
            }
            return
        }
        returnAccounts(accounts)
    }
    
    public func addresses(avm account: Account,
                          chainId: String,
                          hrp: String,
                          change: Bool) -> [Address] {
        self.syncQueue.sync {
            guard let addresses = self.addresses[account] else {
                return []
            }
            return addresses
                .filter {
                    $0.key.chainId == chainId
                        && $0.key.hrp == hrp
                        && $0.value.isChange == change
                }
                .map { $0.key }
        }
    }
    
    public func newAddresses(avm account: Account,
                             chainId: String,
                             hrp: String,
                             change: Bool,
                             count: Int) -> [Address] {
        let from = lastAddressIndex(
            avm: account, chainId: chainId, hrp: hrp, change: change
        ) + 1
        let newAddresses = generateMoreAddresses(
            avm: account, chainId: chainId, hrp: hrp, change: change, from: from, count: count
        )
        self.syncQueue.sync {
            var addresses = self.addresses[account] ?? [:]
            for address in newAddresses {
                addresses[address.address] = address.path
            }
            self.addresses[account] = addresses
        }
        return newAddresses.map { $0.address }
    }
    
    public func extended(avm addresses: [Address]) throws -> [ExtendedAddress] {
        return try self.syncQueue.sync {
            return try addresses.map { addr in
                let kv = self.addresses.reduce(nil) { (found, kv) in
                    found ?? kv.value.first { $0.key == addr }
                }
                guard let found = kv else {
                    throw AvalancheAddressManagerError.addressNotFound(
                        address: addr.bech
                    )
                }
                return try found.key.extended(path: found.value)
            }
        }
    }
    
    public func extended(eth addresses: [EthAddress]) throws -> [EthAccount] {
        return try self.syncQueue.sync {
            let accounts = self.accountsCache?.ethereum ?? []
            return try addresses.map { addr in
                let extended = accounts.first { $0.address == addr }
                if let account = extended {
                    return account
                }
                throw AvalancheAddressManagerError.addressNotFound(
                    address: addr.hex()
                )
            }
        }
    }
    
    public func fetchMoreAddresses(
        avm account: Account,
        chainId: String, hrp: String, change: Bool,
        filter: @escaping AddressUsedFilterCallback<Address>
    ) {
        let from = lastAddressIndex(
            avm: account, chainId: chainId, hrp: hrp, change: change
        ) + 1
        // TODO: IMPLEMENT
    }
    
    private func lastAddressIndex(avm account: Account,
                                  chainId: String,
                                  hrp: String,
                                  change: Bool) -> Int {
        return self.syncQueue.sync {
            let addresses = self.addresses[account] ?? [:]
            return addresses.filter {
                $0.key.chainId == chainId
                    && $0.key.hrp == hrp
                    && $0.value.isChange == change
            }.count
        } - 1
    }
    
    private func generateMoreAddresses(avm account: Account,
                                       chainId: String,
                                       hrp: String,
                                       change: Bool,
                                       from: Int,
                                       count: Int) -> [ExtendedAddress] {
        var newAddresses = [ExtendedAddress]()
        newAddresses.reserveCapacity(count)
        for index in from..<from+count {
           let extended = try! account.derive(index: UInt32(index),
                                              change: change,
                                              hrp: hrp,
                                              chainId: chainId)
            newAddresses.append(extended)
        }
        return newAddresses
    }
}

public protocol AvalancheApiAddressManager {
    associatedtype Acct: AccountProtocol
  
    func accounts(result: @escaping (AvalancheSignatureProviderResult<[Acct]>) -> Void)
    func accounts(forceUpdate: Bool,
                  result: @escaping (AvalancheSignatureProviderResult<[Acct]>) -> Void)
    func extended(for addresses: [Acct.Addr]) throws -> [Acct.Addr.Extended]
}

public protocol AvalancheApiUTXOAddressManager: AvalancheApiAddressManager {
    func addresses(for account: Acct, change: Bool) -> [Acct.Addr]
    func newAddress(for account: Acct) -> Acct.Addr
    func newChange(for account: Acct) -> Acct.Addr
    func newAddresses(for account: Acct, change: Bool, count: Int) -> [Acct.Addr]
    
    func fetchMoreAddresses(for account: Acct, change: Bool, maxCount: Int,
                            result: @escaping ApiCallback<[Acct.Addr]>)
    func fetchMoreAddresses(for account: Acct, maxCount: Int,
                            result: @escaping ApiCallback<[Acct.Addr]>)
}

public extension AvalancheApiUTXOAddressManager {
    func newAddress(for account: Acct) -> Acct.Addr {
        newAddresses(for: account, change: false, count: 1)[0]
    }
    func newChange(for account: Acct) -> Acct.Addr {
        newAddresses(for: account, change: true, count: 1)[0]
    }
    
    func fetchMoreAddresses(for account: Acct, maxCount: Int,
                            result: @escaping ApiCallback<[Acct.Addr]>) {
        fetchMoreAddresses(for: account, change: false, maxCount: maxCount) {
            switch $0 {
            case .failure(let err): result(.failure(err))
            case .success(let addresses):
                fetchMoreAddresses(for: account, change: true, maxCount: maxCount) {
                    result($0.map{ addresses + $0 })
                }
            }
        }
    }
}
