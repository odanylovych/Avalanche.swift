//
//  MockProviders.swift
//  
//
//  Created by Ostap Danylovych on 25.11.2021.
//

import Foundation
import Avalanche
import RPC

enum ApiTestsError: Error {
    case error(from: String)
    case error(description: String)
}

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
    var getAPIMock: ((Any.Type) throws -> Any)?
    var createAPIMock: ((NetworkID, String, Any) -> Any)?
    
    var networkID: NetworkID
    var networkInfoProvider: AvalancheNetworkInfoProvider
    var settings: AvalancheSettings
    var addressManager: AvalancheAddressManager?
    var utxoProvider: AvalancheUtxoProvider
    var signatureProvider: AvalancheSignatureProvider?
    var connectionProvider: AvalancheConnectionProvider
    
    init(
        networkID: NetworkID = NetworkID.local,
        networkInfoProvider: AvalancheNetworkInfoProvider = NetworkInfoProviderMock(),
        settings: AvalancheSettings = AvalancheSettings.default,
        addressManager: AvalancheAddressManager? = AddressManagerMock(),
        utxoProvider: AvalancheUtxoProvider = UtxoProviderMock(),
        signatureProvider: AvalancheSignatureProvider = SignatureProviderMock(),
        connectionProvider: AvalancheConnectionProvider = ConnectionProviderMock()
    ) {
        self.networkID = networkID
        self.networkInfoProvider = networkInfoProvider
        self.settings = settings
        self.addressManager = addressManager
        self.utxoProvider = utxoProvider
        self.signatureProvider = signatureProvider
        self.connectionProvider = connectionProvider
    }
    
    func getAPI<A: AvalancheApi>() throws -> A {
        try getAPIMock!(A.self) as! A
    }
    
    func createAPI<A: AvalancheApi>(networkID: NetworkID, hrp: String, info: A.Info) -> A {
        createAPIMock!(networkID, hrp, info) as! A
    }
    
    func defaultGetAPIMock(for networkID: NetworkID) -> (Any.Type) throws -> Any {
        { apiType in
            let networkInfo = AvalancheDefaultNetworkInfoProvider.default.info(for: networkID)!
            if apiType == AvalancheXChainApi.self {
                return AvalancheXChainApi(
                    avalanche: self,
                    networkID: networkID,
                    hrp: networkInfo.hrp,
                    info: networkInfo.apiInfo.info(for: AvalancheXChainApi.self)!
                )
            } else if apiType == AvalanchePChainApi.self {
                return AvalanchePChainApi(
                    avalanche: self,
                    networkID: networkID,
                    hrp: networkInfo.hrp,
                    info: networkInfo.apiInfo.info(for: AvalanchePChainApi.self)!
                )
            } else if apiType == AvalancheCChainApi.self {
                return AvalancheCChainApi(
                    avalanche: self,
                    networkID: networkID,
                    hrp: networkInfo.hrp,
                    info: networkInfo.apiInfo.info(for: AvalancheCChainApi.self)!
                )
            } else {
                throw ApiTestsError.error(from: "getAPIMock")
            }
        }
    }
}

struct ConnectionProviderMock: AvalancheConnectionProvider {
    var singleShotMock: ((ApiConnectionType) -> SingleShotConnection)?
    var rpcMock: ((ApiConnectionType) -> Client)?
    var subscribableRPCMock: ((ApiConnectionType) -> PersistentConnection?)?
    
    func singleShot(api: ApiConnectionType) -> SingleShotConnection {
        singleShotMock!(api)
    }
    
    func rpc(api: ApiConnectionType) -> Client {
        rpcMock!(api)
    }
    
    func subscribableRPC(api: ApiConnectionType) -> PersistentConnection? {
        subscribableRPCMock!(api)
    }
}

struct ClientMock: Client {
    var callMock: ((String, Any, @escaping (Result<Any, Error>) -> Void) -> Void)?
    
    func call<Params: Encodable, Res: Decodable, Err: Decodable>(
        method: String,
        params: Params,
        _ res: Res.Type,
        _ err: Err.Type,
        response: @escaping RequestCallback<Params, Res, Err>
    ) {
        callMock!(method, params) { res in
            response(res.mapError {
                .custom(description: "callMock error", cause: $0)
            }.map { $0 as! Res })
        }
    }
}

class SignatureProviderMock: AvalancheSignatureProvider {
    var accountsMock: ((
        AvalancheSignatureProviderAccountRequestType,
        @escaping (AvalancheSignatureProviderResult<AvalancheSignatureProviderAccounts>) -> Void
    ) -> Void)?
    var signTransactionMock: ((Any, @escaping (AvalancheSignatureProviderResult<Any>) -> Void) -> Void)?
    var signMessageMock: ((Data, Any, @escaping (AvalancheSignatureProviderResult<Signature>) -> Void) -> Void)?
    
    func accounts(type: AvalancheSignatureProviderAccountRequestType,
                  _ cb: @escaping (AvalancheSignatureProviderResult<AvalancheSignatureProviderAccounts>) -> Void) {
        accountsMock!(type, cb)
    }
    
    func sign<T: ExtendedUnsignedTransaction>(transaction: T,
                                              _ cb: @escaping (AvalancheSignatureProviderResult<T.Signed>) -> Void) {
        signTransactionMock!(transaction) { res in
            cb(res.map { $0 as! T.Signed })
        }
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
        let nextMock: ((UInt32?, BlockchainID?,
                        @escaping ApiCallback<(utxos: [UTXO], iterator: AvalancheUtxoProviderIterator?)>) -> Void)?
        
        func next(limit: UInt32? = nil,
                  sourceChain: BlockchainID? = nil,
                  result: @escaping ApiCallback<(utxos: [UTXO], iterator: AvalancheUtxoProviderIterator?)>) {
            nextMock!(limit, sourceChain, result)
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
    let connectionType: ApiConnectionType
    
    init(
        blockchainID: BlockchainID = BlockchainID(data: Data(count: BlockchainID.size))!,
        alias: String? = nil,
        vm: String = "vm",
        apiPath: ApiConnectionType = .xChain(
            alias: "alias",
            blockchainID: BlockchainID(data: Data(count: BlockchainID.size))!
        )
    ) {
        self.blockchainID = blockchainID
        self.alias = alias
        self.vm = vm
        self.connectionType = apiPath
    }
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
    
    init(
        avalanche: AvalancheCore,
        networkID: NetworkID = NetworkID.local,
        hrp: String = "hrp",
        info: AvalancheVMApiInfoMock = AvalancheVMApiInfoMock()
    ) {
        self.avalanche = avalanche
        addressManager = avalanche.addressManager
        self.networkID = networkID
        self.hrp = hrp
        self.info = info
    }
    
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
