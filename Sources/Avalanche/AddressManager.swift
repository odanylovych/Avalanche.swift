//
//  AddressManager.swift
//  
//
//  Created by Yehor Popovych on 01.09.2021.
//

import Foundation

public enum AvalancheAddressManagerError: Error {
    case addressNotFound(address: String)
    case notInCache(account: Account)
}

public protocol AvalancheAddressManager: AnyObject {
    func start(avalanche: AvalancheCore)
    
    // Returns list of accounts
    func accounts(type: AvalancheSignatureProviderAccountRequestType,
                  _ cb: @escaping (AvalancheSignatureProviderResult<AvalancheSignatureProviderAccounts>) -> Void)
    
    // Creates and caches new addresses for the Account
    func new<A: AvalancheVMApi>(avm api: A,
                                for account: Account,
                                change: Bool,
                                count: Int) throws -> [Address]
    
    // Get cached addresses for the Account. Throws if unknown account (not fetched)
    func get<A: AvalancheVMApi>(avm api: A, cached account: Account) throws -> [Address]
    
    // Fetches list of addresses for account from the network.
    func get<A: AvalancheVMApi>(avm api: A,
                                for account: Account,
                                _ cb: @escaping (Result<[Address], Error>) -> Void)
    
    // Updates cached addresses for Accounts from the network
    func fetch<A: AvalancheVMApi>(avm api: A,
                                  for accounts: [Account],
                                  _ cb: @escaping (Result<Void, Error>) -> Void)
    
    // Obtains accounts from Signer and fetches all of them
    func fetch<A: AvalancheVMApi>(avm api: A,
                                  _ cb: @escaping (Result<Void, Error>) -> Void)
    
    // Returns list of accounts
    func fetchedAccounts() -> AvalancheSignatureProviderAccounts
    
    // Returns extended addresses for provided addresses
    func extended(avm addresses: [Address]) throws -> [ExtendedAddress]
    func extended(eth addresses: [EthAddress]) throws -> [EthAccount]
}

public protocol AvalancheApiAddressManager {
    associatedtype Acct: AccountProtocol
    
    func accounts(result: @escaping (AvalancheSignatureProviderResult<[Acct]>) -> Void)
    func extended(for addresses: [Acct.Addr]) throws -> [Acct.Addr.Extended]
}

public protocol AvalancheApiUTXOAddressManager: AvalancheApiAddressManager {
    func new(for account: Acct, change: Bool, count: Int) throws -> [Acct.Addr]
    func newAddress(for account: Acct) throws -> Acct.Addr
    func newChange(for account: Acct) throws -> Acct.Addr
    func randomChange(for account: Acct) throws -> Acct.Addr
    
    func get(cached account: Acct) throws -> [Acct.Addr]
    func get(for account: Acct, _ cb: @escaping (Result<[Acct.Addr], Error>) -> Void)
    
    func fetch(for accounts: [Acct], _ cb: @escaping (Result<Void, Error>) -> Void)
    func fetch(_ cb: @escaping (Result<Void, Error>) -> Void)
    
    func fetchedAccounts() -> [Acct]
}

public extension AvalancheApiUTXOAddressManager {
    func newAddress(for account: Acct) throws -> Acct.Addr {
        try new(for: account, change: false, count: 1)[0]
    }
    
    func newChange(for account: Acct) throws -> Acct.Addr {
        try new(for: account, change: true, count: 1)[0]
    }
    
    func randomChange(for account: Acct) throws -> Acct.Addr {
        let addresses = try self.extended(for: try self.get(cached: account)).filter {
            $0.isChange
        }.map { $0.address }
        if addresses.count == 0 {
            return try newChange(for: account)
        }
        return addresses.randomElement()!
    }
}

public class AvalancheDefaultAddressManager: AvalancheAddressManager {
    private static let fetchChunkSize = 20
    
    public private (set) weak var avalanche: AvalancheCore!

    public let signer: AvalancheSignatureProvider
    
    private var queue: DispatchQueue { avalanche.settings.queue }
    private var accountsCache: AvalancheSignatureProviderAccounts?
    private var syncQueue: DispatchQueue
    private var addresses: Dictionary<Account, Dictionary<Address, Bip32Path>>
    
    public init(signer: AvalancheSignatureProvider) {
        self.signer = signer
        self.accountsCache = nil
        self.syncQueue = DispatchQueue(
            label: "address.manager.internal.sync.queue",
            qos: .userInitiated,
            target: .global(qos: .userInitiated)
        )
        self.addresses = [:]
    }
    
    public func start(avalanche: AvalancheCore) {
        self.avalanche = avalanche
    }
    
    public func accounts(type: AvalancheSignatureProviderAccountRequestType,
                         _ cb: @escaping (AvalancheSignatureProviderResult<AvalancheSignatureProviderAccounts>) -> Void) {
        signer.accounts(type: .both) { res in
            switch res {
            case .success(let accounts):
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
            case .failure(let err):
                self.queue.async { cb(.failure(err)) }
            }
        }
    }
    
    public func new<A: AvalancheVMApi>(avm api: A,
                                       for account: Account,
                                       change: Bool,
                                       count: Int) throws -> [Address] {
        let from = lastAddressIndex(
            avm: account, chainId: api.info.chainId, hrp: api.hrp, change: change
        ) + 1
        let newAddresses = generateMoreAddresses(
            avm: account, chainId: api.info.chainId, hrp: api.hrp, change: change, from: from, count: count
        )
        try self.syncQueue.sync {
            guard var addresses = self.addresses[account] else {
                throw AvalancheAddressManagerError.notInCache(account: account)
            }
            for address in newAddresses {
                addresses[address.address] = address.path
            }
            self.addresses[account] = addresses
        }
        return newAddresses.map { $0.address }
    }
    
    public func get<A: AvalancheVMApi>(avm api: A, cached account: Account) throws -> [Address] {
        try self.syncQueue.sync {
            guard let addresses = self.addresses[account] else {
                throw AvalancheAddressManagerError.notInCache(account: account)
            }
            return addresses
                .filter {
                    $0.key.chainId == api.info.chainId
                        && $0.key.hrp == api.hrp
                }
                .map { $0.key }
        }
    }
    
    public func get<A: AvalancheVMApi>(avm api: A,
                                       for account: Account,
                                       _ cb: @escaping (Result<[Address], Error>) -> Void) {
        fetch(avm: api, for: [account]) { res in
            cb(res.flatMap {
                Result { try self.get(avm: api, cached: account) }
            })
        }
    }
    
    private func fetchNext<A: AvalancheVMApi>(avm api: A,
                           for account: Account,
                           index: Int,
                           all: [(ExtendedAddress, Bool)],
                           change: Bool,
                           _ cb: @escaping (Result<[ExtendedAddress], Error>) -> Void) {
        let addresses: [ExtendedAddress]
        do {
            addresses = try (0..<Self.fetchChunkSize).map { offset in
                try account.derive(
                    index: UInt32(index + offset),
                    change: change,
                    hrp: api.hrp,
                    chainId: api.info.chainId
                )
            }
        } catch {
            cb(.failure(error))
            return
        }
        let iterator = avalanche.utxoProvider.utxos(api: api, addresses: addresses.map { $0.address })
        UTXOHelper.getAll(iterator: iterator) { res in
            switch res {
            case .success(let utxos):
                let addressesInUtxos = Set(utxos.flatMap { $0.output.addresses })
                let addresses = addresses.map { ($0, addressesInUtxos.contains($0.address)) }
                let all = all + addresses
                guard let lastInAll = all.lastIndex(where: { $0.1 }) else {
                    cb(.success([]))
                    return
                }
                let dropEmpty = { all.dropLast(all.count - lastInAll - 1) }
                if all.count - lastInAll > Self.fetchChunkSize {
                    cb(.success(dropEmpty().map { $0.0 }))
                } else {
                    let lastInNewAddresses = addresses.lastIndex(where: { $0.1 })!
                    self.fetchNext(
                        avm: api,
                        for: account,
                        index: index + lastInNewAddresses + 1,
                        all: Array(dropEmpty()),
                        change: change,
                        cb
                    )
                }
            case .failure(let error):
                cb(.failure(error))
            }
        }
    }
    
    public func fetch<A: AvalancheVMApi>(avm api: A,
                                         for accounts: [Account],
                                         _ cb: @escaping (Result<Void, Error>) -> Void) {
        [true, false].asyncMap { change, mapped in
            accounts.asyncMap { account, mapped in
                self.fetchNext(
                    avm: api,
                    for: account,
                    index: self.lastAddressIndex(
                        avm: account,
                        chainId: api.info.chainId,
                        hrp: api.hrp,
                        change: change
                    ) + 1,
                    all: [],
                    change: change
                ) { res in
                    mapped(res.map { addresses in
                        self.syncQueue.sync {
                            var cacheAddresses = self.addresses[account] ?? [:]
                            addresses.forEach { extended in
                                cacheAddresses[extended.address] = extended.path
                            }
                            self.addresses[account] = cacheAddresses
                        }
                    })
                }
            }.exec(mapped)
        }.exec { cb($0.map { _ in }) }
    }
    
    public func fetch<A: AvalancheVMApi>(avm api: A,
                                         _ cb: @escaping (Result<Void, Error>) -> Void) {
        accounts(type: .both) { res in
            switch res {
            case .failure(let err): cb(.failure(err))
            case .success(let accounts):
                self.syncQueue.sync {
                    self.accountsCache = accounts
                }
                self.fetch(avm: api, for: accounts.avalanche, cb)
            }
        }
    }
    
    public func fetchedAccounts() -> AvalancheSignatureProviderAccounts {
        syncQueue.sync {
            accountsCache ?? (avalanche: [], ethereum: [])
        }
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
