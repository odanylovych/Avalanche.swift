//
//  MockProviders.swift
//  
//
//  Created by Ostap Danylovych on 25.11.2021.
//

import Foundation
import Avalanche

struct NetworkInfoProviderMock: AvalancheNetworkInfoProvider {
    var infoMock: ((NetworkID) -> AvalancheNetworkInfo?)?
    var setInfoMock: ((AvalancheNetworkInfo, NetworkID) -> Void)?
    
    func info(for net: NetworkID) -> AvalancheNetworkInfo? {
        infoMock!(net)
    }
    
    func setInfo(info: AvalancheNetworkInfo, for net: NetworkID) {
        setInfoMock!(info, net)
    }
}

class AvalancheCoreMock: AvalancheCore {
    var getAPIMock: (() throws -> Any)?
    var createAPIMock: ((NetworkID, String, Any) -> Any)?
    var urlMock: ((String) -> URL)?
    
    var networkID: NetworkID
    var networkInfoProvider: AvalancheNetworkInfoProvider
    var settings: AvalancheSettings
    var addressManager: AvalancheAddressManager?
    var utxoProvider: AvalancheUtxoProvider
    
    init(
        networkID: NetworkID,
        networkInfoProvider: AvalancheNetworkInfoProvider,
        settings: AvalancheSettings,
        addressManager: AvalancheAddressManager?,
        utxoProvider: AvalancheUtxoProvider
    ) {
        self.networkID = networkID
        self.networkInfoProvider = networkInfoProvider
        self.settings = settings
        self.addressManager = addressManager
        self.utxoProvider = utxoProvider
    }
    
    static let `default` = AvalancheCoreMock(
        networkID: NetworkID.local,
        networkInfoProvider:  NetworkInfoProviderMock(),
        settings:  AvalancheSettings.default,
        addressManager:  AddressManagerMock(),
        utxoProvider:  UtxoProviderMock()
    )
    
    func getAPI<A: AvalancheApi>() throws -> A {
        try getAPIMock!() as! A
    }
    
    func createAPI<A: AvalancheApi>(networkID: NetworkID, hrp: String, info: A.Info) -> A {
        createAPIMock!(networkID, hrp, info) as! A
    }
    
    func url(path: String) -> URL {
        urlMock!(path)
    }
}

class SignatureProviderMock: AvalancheSignatureProvider {
    var accountsMock: ((
        AvalancheSignatureProviderAccountRequestType,
        @escaping (AvalancheSignatureProviderResult<AvalancheSignatureProviderAccounts>) -> Void
    ) -> Void)?
    var signTransactionMock: ((Any, Any) -> Void)?
    var signMessageMock: ((Data, Any, @escaping (AvalancheSignatureProviderResult<Signature>) -> Void) -> Void)?
    
    func accounts(type: AvalancheSignatureProviderAccountRequestType,
                  _ cb: @escaping (AvalancheSignatureProviderResult<AvalancheSignatureProviderAccounts>) -> Void) {
        accountsMock!(type, cb)
    }
    
    func sign<T: ExtendedUnsignedTransaction>(transaction: T,
                                              _ cb: @escaping (AvalancheSignatureProviderResult<T.Signed>) -> Void) {
        signTransactionMock!(transaction, cb)
    }
    
    func sign<A: ExtendedAddressProtocol>(message: Data,
                                          address: A,
                                          _ cb: @escaping (AvalancheSignatureProviderResult<Signature>) -> Void) {
        signMessageMock!(message, address, cb)
    }
}

class AddressManagerMock: AvalancheAddressManager {
    var accountsMock: ((
        AvalancheSignatureProviderAccountRequestType,
        @escaping (AvalancheSignatureProviderResult<AvalancheSignatureProviderAccounts>) -> Void
    ) -> Void)?
    var newMock: ((Any, Account, Bool, Int) throws -> [Address])?
    var getCachedMock: ((Any, Account) throws -> [Address])?
    var getForAccountMock: ((Any, Account, @escaping (Result<[Address], Error>) -> Void) -> Void)?
    var fetchForAccountsMock: ((Any, [Account], @escaping (Result<Void, Error>) -> Void) -> Void)?
    var fetchMock: ((Any, @escaping (Result<Void, Error>) -> Void) -> Void)?
    var fetchedAccountsMock: (() -> AvalancheSignatureProviderAccounts)?
    var extendedAvmMock: (([Address]) throws -> [ExtendedAddress])?
    var extendedEthMock: (([EthAddress]) throws -> [EthAccount])?
    
    var avalanche: AvalancheCore!
    
    func start(avalanche: AvalancheCore) {
        self.avalanche = avalanche
    }
    
    func accounts(type: AvalancheSignatureProviderAccountRequestType, _ cb: @escaping (AvalancheSignatureProviderResult<AvalancheSignatureProviderAccounts>) -> Void) {
        accountsMock!(type, cb)
    }
    
    func new<A>(avm api: A, for account: Account, change: Bool, count: Int) throws -> [Address] where A : AvalancheVMApi {
        try newMock!(api, account, change, count)
    }
    
    func get<A>(avm api: A, cached account: Account) throws -> [Address] where A : AvalancheVMApi {
        try getCachedMock!(api, account)
    }
    
    func get<A>(avm api: A, for account: Account, _ cb: @escaping (Result<[Address], Error>) -> Void) where A : AvalancheVMApi {
        getForAccountMock!(api, account, cb)
    }
    
    func fetch<A>(avm api: A, for accounts: [Account], _ cb: @escaping (Result<Void, Error>) -> Void) where A : AvalancheVMApi {
        fetchForAccountsMock!(api, accounts, cb)
    }
    
    func fetch<A>(avm api: A, _ cb: @escaping (Result<Void, Error>) -> Void) where A : AvalancheVMApi {
        fetchMock!(api, cb)
    }
    
    func fetchedAccounts() -> AvalancheSignatureProviderAccounts {
        fetchedAccountsMock!()
    }
    
    func extended(avm addresses: [Address]) throws -> [ExtendedAddress] {
        try extendedAvmMock!(addresses)
    }
    
    func extended(eth addresses: [EthAddress]) throws -> [EthAccount] {
        try extendedEthMock!(addresses)
    }
}

class UtxoProviderMock: AvalancheUtxoProvider {
    var utxosIdsMock: ((Any, [(txID: TransactionID, index: UInt32)], @escaping ApiCallback<[UTXO]>) -> Void)?
    var utxosAddressesMock: ((Any, [Address]) -> AvalancheUtxoProviderIterator)?
    
    struct IteratorMock: AvalancheUtxoProviderIterator {
        let nextMock: ((UInt32?, @escaping ApiCallback<(utxos: [UTXO], iterator: AvalancheUtxoProviderIterator?)>) -> Void)?
        
        func next(limit: UInt32?, result: @escaping ApiCallback<(utxos: [UTXO], iterator: AvalancheUtxoProviderIterator?)>) {
            nextMock!(limit, result)
        }
    }
    
    func utxos<A: AvalancheVMApi>(api: A, ids: [(txID: TransactionID, index: UInt32)], result: @escaping ApiCallback<[UTXO]>) {
        utxosIdsMock!(api, ids, result)
    }
    
    func utxos<A: AvalancheVMApi>(api: A, addresses: [Address]) -> AvalancheUtxoProviderIterator {
        utxosAddressesMock!(api, addresses)
    }
}

struct AvalancheApiUTXOAddressManagerMock: AvalancheApiUTXOAddressManager {
    typealias Acct = Account
    
    let manager: AvalancheAddressManager
    let api: AvalancheVMApiMock
    
    init(manager: AvalancheAddressManager, api: AvalancheVMApiMock) {
        self.manager = manager
        self.api = api
    }
    
    func accounts(result: @escaping (AvalancheSignatureProviderResult<[Acct]>) -> Void) {
        manager.accounts(type: .avalancheOnly) {
            result($0.map { $0.avalanche })
        }
    }
    
    func extended(for addresses: [Acct.Addr]) throws -> [Acct.Addr.Extended] {
        try manager.extended(avm: addresses)
    }
    
    func new(for account: Acct, change: Bool, count: Int) throws -> [Acct.Addr] {
        try manager.new(avm: api, for: account, change: change, count: count)
    }
    
    func get(cached account: Acct) throws -> [Acct.Addr] {
        try manager.get(avm: api, cached: account)
    }
    
    func get(for account: Acct, _ cb: @escaping (Result<[Acct.Addr], Error>) -> Void) {
        manager.get(avm: api, for: account, cb)
    }
    
    func fetch(for accounts: [Acct], _ cb: @escaping (Result<Void, Error>) -> Void) {
        manager.fetch(avm: api, for: accounts, cb)
    }
    
    func fetch(_ cb: @escaping (Result<Void, Error>) -> Void) {
        manager.fetch(avm: api, cb)
    }
    
    func fetchedAccounts() -> [Acct] {
        manager.fetchedAccounts().avalanche
    }
}

class AvalancheVMApiInfoMock: AvalancheVMApiInfo {
    let blockchainID: BlockchainID
    let alias: String?
    let vm: String
    let apiPath: String
    
    init(blockchainID: BlockchainID, alias: String?, vm: String, apiPath: String) {
        self.blockchainID = blockchainID
        self.alias = alias
        self.vm = vm
        self.apiPath = apiPath
    }
    
    static let `default` = AvalancheVMApiInfoMock(
        blockchainID: BlockchainID(data: Data(count: BlockchainID.size))!,
        alias: nil,
        vm: "vm",
        apiPath: "apiPath"
    )
}

struct AvalancheVMApiMock: AvalancheVMApi {
    var getTransactionMock: ((TransactionID, @escaping ApiCallback<SignedAvalancheTransaction>) -> Void)?
    var getUTXOsMock: ((
        [Address],
        UInt32?,
        UTXOIndex?,
        BlockchainID?,
        AvalancheEncoding?,
        @escaping ApiCallback<(
            fetched: UInt32,
            utxos: [UTXO],
            endIndex: UTXOIndex,
            encoding: AvalancheEncoding
        )>
    ) -> Void)?
    
    typealias Keychain = AvalancheApiUTXOAddressManagerMock
    typealias Info = AvalancheVMApiInfoMock
    
    var avalanche: AvalancheCore
    var addressManager: AvalancheAddressManager?
    var networkID: NetworkID
    var hrp: String
    var info: AvalancheVMApiInfoMock
    
    public var keychain: AvalancheApiUTXOAddressManagerMock? {
        addressManager.map {
            AvalancheApiUTXOAddressManagerMock(manager: $0, api: self)
        }
    }
    
    init(avalanche: AvalancheCore, networkID: NetworkID, hrp: String, info: AvalancheVMApiInfoMock) {
        self.avalanche = avalanche
        addressManager = avalanche.addressManager
        self.networkID = networkID
        self.hrp = hrp
        self.info = info
    }
    
    static let `default` = AvalancheVMApiMock(
        avalanche: AvalancheCoreMock.default,
        networkID: NetworkID.local,
        hrp: "hrp",
        info: AvalancheVMApiInfoMock.default
    )
    
    func getTransaction(id: TransactionID, result: @escaping ApiCallback<SignedAvalancheTransaction>) {
        getTransactionMock!(id, result)
    }
    
    func getUTXOs(
        addresses: [Address],
        limit: UInt32?,
        startIndex: UTXOIndex?,
        sourceChain: BlockchainID?,
        encoding: AvalancheEncoding?,
        _ cb: @escaping ApiCallback<(
            fetched: UInt32,
            utxos: [UTXO],
            endIndex: UTXOIndex,
            encoding: AvalancheEncoding
        )>
    ) {
        getUTXOsMock!(addresses, limit, startIndex, sourceChain, encoding, cb)
    }
}
