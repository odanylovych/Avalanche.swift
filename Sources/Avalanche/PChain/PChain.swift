//
//  PChain.swift
//  
//
//  Created by Yehor Popovych on 10/4/20.
//

import Foundation
import BigInt
import Serializable
#if !COCOAPODS
import RPC
#endif

public struct AvalanchePChainApi: AvalancheVMApi {
    public typealias Info = AvalanchePChainApiInfo
    public typealias Keychain = AvalanchePChainApiAddressManager
    
    private let addressManager: AvalancheAddressManager?
    internal let service: Client
    internal let queue: DispatchQueue
    
    public let networkID: NetworkID
    public let hrp: String
    public let info: Info
    
    public var keychain: AvalanchePChainApiAddressManager? {
        addressManager.map {
            AvalanchePChainApiAddressManager(manager: $0, api: self)
        }
    }
    
    private var context: AvalancheDecoderContext {
        DefaultAvalancheDecoderContext(
            hrp: hrp,
            chainId: info.chainId,
            dynamicParser: PChainDynamicTypeRegistry.instance
        )
    }

    public init(avalanche: AvalancheCore,
                networkID: NetworkID,
                hrp: String,
                info: Info)
    {
        let settings = avalanche.settings
        
        self.addressManager = avalanche.addressManager
        self.info = info
        self.hrp = hrp
        self.networkID = networkID
        self.queue = settings.queue
        
        let url = avalanche.url(path: info.apiPath)
        
        self.service = JsonRpc(.http(url: url, session: settings.session, headers: settings.headers), queue: settings.queue, encoder: settings.encoder, decoder: settings.decoder)
    }
    
    public struct AddDelegatorParams: Encodable {
        public let nodeID: String
        public let startTime: Int64
        public let endTime: Int64
        public let stakeAmount: UInt64
        public let rewardAddress: String
        public let from: Array<String>?
        public let changeAddr: String?
        public let username: String
        public let password: String
    }
    
    public struct AddDelegatorResponse: Decodable {
        public let txID: String
        public let changeAddr: String
    }
    
    public func addDelegator(
        nodeID: NodeID, startTime: Date, endTime: Date, stakeAmount: UInt64,
        reward: Address, from: Array<Address>? = nil, change: Address? = nil,
        credentials: AvalancheVmApiCredentials,
        _ cb: @escaping ApiCallback<(txID: TransactionID, change: Address)>
    ) {
        switch credentials {
        case .password(username: let user, password: let pass):
            let params = AddDelegatorParams(
                nodeID: nodeID.cb58(),
                startTime: Int64(startTime.timeIntervalSince1970),
                endTime: Int64(endTime.timeIntervalSince1970),
                stakeAmount: stakeAmount, rewardAddress: reward.bech,
                from: from.map { $0.map { $0.bech } },
                changeAddr: change?.bech, username: user, password: pass)
            service.call(method: "platform.addDelegator",
                         params: params,
                         AddDelegatorResponse.self,
                         SerializableValue.self) { res in
                cb(res
                    .mapError(AvalancheApiError.init)
                    .map { (TransactionID(cb58: $0.txID)!, try! Address(bech: $0.changeAddr)) })
            }
        case .account(let account):
            txAddDelegator(nodeID: nodeID, startTime: startTime, endTime: endTime,
                           stakeAmount: stakeAmount, reward: reward,
                           from: from, change: change, account: account, cb)
        }
    }
    
    public struct AddValidatorParams: Encodable {
        public let nodeID: String
        public let startTime: Int64
        public let endTime: Int64
        public let stakeAmount: UInt64
        public let rewardAddress: String
        public let delegationFeeRate: Float
        public let from: [String]?
        public let changeAddr: String?
        public let username: String
        public let password: String
    }
    
    public struct AddValidatorResponse: Decodable {
        public let txID: String
        public let changeAddr: String
    }
    
    public func addValidator(
        nodeID: NodeID,
        startTime: Date,
        endTime: Date,
        stakeAmount: UInt64,
        reward: Address,
        delegationFeeRate: Float,
        from: [Address]? = nil,
        change: Address? = nil,
        credentials: AvalancheVmApiCredentials,
        _ cb: @escaping ApiCallback<(txID: TransactionID, change: Address)>
    ) {
        switch credentials {
        case .password(let username, let password):
            let params = AddValidatorParams(
                nodeID: nodeID.cb58(),
                startTime: Int64(startTime.timeIntervalSince1970),
                endTime: Int64(endTime.timeIntervalSince1970),
                stakeAmount: stakeAmount,
                rewardAddress: reward.bech,
                delegationFeeRate: delegationFeeRate,
                from: from?.map { $0.bech },
                changeAddr: change?.bech,
                username: username,
                password: password
            )
            service.call(
                method: "platform.addValidator",
                params: params,
                AddValidatorResponse.self,
                SerializableValue.self
            ) { res in
                cb(res
                    .mapError(AvalancheApiError.init)
                    .map { (TransactionID(cb58: $0.txID)!, try! Address(bech: $0.changeAddr)) })
            }
        case .account:
            fatalError("Not implemented")
        }
    }
    
    public struct AddSubnetValidatorParams: Encodable {
        public let nodeID: String
        public let subnetID: String
        public let startTime: Int64
        public let endTime: Int64
        public let weight: UInt64
        public let from: [String]?
        public let changeAddr: String?
        public let username: String
        public let password: String
    }
    
    public struct AddSubnetValidatorResponse: Decodable {
        public let txID: String
        public let changeAddr: String
    }
    
    public func addSubnetValidator(
        nodeID: NodeID,
        subnetID: BlockchainID,
        startTime: Date,
        endTime: Date,
        weight: UInt64,
        from: [Address]? = nil,
        change: Address? = nil,
        credentials: AvalancheVmApiCredentials,
        _ cb: @escaping ApiCallback<(txID: TransactionID, change: Address)>
    ) {
        switch credentials {
        case .password(let username, let password):
            let params = AddSubnetValidatorParams(
                nodeID: nodeID.cb58(),
                subnetID: subnetID.cb58(),
                startTime: Int64(startTime.timeIntervalSince1970),
                endTime: Int64(endTime.timeIntervalSince1970),
                weight: weight,
                from: from?.map { $0.bech },
                changeAddr: change?.bech,
                username: username,
                password: password
            )
            service.call(
                method: "platform.addSubnetValidator",
                params: params,
                AddSubnetValidatorResponse.self,
                SerializableValue.self
            ) { res in
                cb(res
                    .mapError(AvalancheApiError.init)
                    .map { (TransactionID(cb58: $0.txID)!, try! Address(bech: $0.changeAddr)) })
            }
        case .account:
            fatalError("Not implemented")
        }
    }
    
    public struct CreateAddressParams: Encodable {
        public let username: String
        public let password: String
    }
    
    public struct CreateAddressResponse: Decodable {
        public let address: String
    }
    
    public func createAddress(
        credentials: AvalancheVmApiCredentials,
        _ cb: @escaping ApiCallback<Address>) {
        switch credentials {
        case .password(username: let user, password: let pass):
            service.call(method: "platform.createAddress",
                         params: CreateAddressParams(username: user, password: pass),
                         CreateAddressResponse.self,
                         SerializableValue.self) { res in
                cb(res.mapError(AvalancheApiError.init).map { try! Address(bech: $0.address) }) // TODO: error handling
            }
        case .account(let account):
            self.queue.async {
                guard let kc = keychain else {
                    cb(.failure(.nilAddressManager))
                    return
                }
                cb(Result { try kc.newAddress(for: account) }.mapError {
                    AvalancheApiError.custom(description: "Cannot create new address", cause: $0)
                })
            }
        }
    }
    
    public struct CreateBlockchainParams: Encodable {
        public let subnetID: String
        public let vmID: String
        public let name: String
        public let genesisData: String
        public let encoding: AvalancheEncoding?
        public let from: [String]?
        public let changeAddr: String?
        public let username: String
        public let password: String
    }
    
    public struct CreateBlockchainResponse: Decodable {
        public let txID: String
        public let changeAddr: String
    }
    
    public func createBlockchain(
        subnetID: BlockchainID,
        vmID: String,
        name: String,
        genesisData: String,
        encoding: AvalancheEncoding? = nil,
        from: [Address]? = nil,
        change: Address? = nil,
        credentials: AvalancheVmApiCredentials,
        _ cb: @escaping ApiCallback<(txID: TransactionID, change: Address)>
    ) {
        switch credentials {
        case .password(let username, let password):
            let params = CreateBlockchainParams(
                subnetID: subnetID.cb58(),
                vmID: vmID,
                name: name,
                genesisData: genesisData,
                encoding: encoding,
                from: from?.map { $0.bech },
                changeAddr: change?.bech,
                username: username,
                password: password
            )
            service.call(
                method: "platform.createBlockchain",
                params: params,
                CreateBlockchainResponse.self,
                SerializableValue.self
            ) { res in
                cb(res
                    .mapError(AvalancheApiError.init)
                    .map { (TransactionID(cb58: $0.txID)!, try! Address(bech: $0.changeAddr)) })
            }
        case .account:
            fatalError("Not implemented")
        }
    }
    
    public struct CreateSubnetParams: Encodable {
        public let controlKeys: [String]
        public let threshold: UInt32
        public let from: [String]?
        public let changeAddr: String?
        public let username: String
        public let password: String
    }
    
    public struct CreateSubnetResponse: Decodable {
        public let txID: String
        public let changeAddr: String
    }
    
    public func createSubnet(
        controlKeys: [Address],
        threshold: UInt32,
        from: [Address]? = nil,
        change: Address? = nil,
        credentials: AvalancheVmApiCredentials,
        _ cb: @escaping ApiCallback<(txID: TransactionID, change: Address)>
    ) {
        switch credentials {
        case .password(let username, let password):
            let params = CreateSubnetParams(
                controlKeys: controlKeys.map { $0.bech },
                threshold: threshold,
                from: from?.map { $0.bech },
                changeAddr: change?.bech,
                username: username,
                password: password
            )
            service.call(
                method: "platform.createSubnet",
                params: params,
                CreateSubnetResponse.self,
                SerializableValue.self
            ) { res in
                cb(res
                    .mapError(AvalancheApiError.init)
                    .map { (TransactionID(cb58: $0.txID)!, try! Address(bech: $0.changeAddr)) })
            }
        case .account:
            fatalError("Not implemented")
        }
    }
    
    public struct ExportAVAXParams: Encodable {
        public let amount: UInt64
        public let from: [String]?
        public let to: String
        public let changeAddr: String?
        public let username: String
        public let password: String
    }
    
    public struct ExportAVAXResponse: Decodable {
        public let txID: String
        public let changeAddr: String
    }
    
    public func exportAVAX(
        to: Address,
        amount: UInt64,
        from: [Address]? = nil,
        change: Address? = nil,
        credentials: AvalancheVmApiCredentials,
        _ cb: @escaping ApiCallback<(txID: TransactionID, change: Address)>
    ) {
        switch credentials {
        case .password(let username, let password):
            let params = ExportAVAXParams(
                amount: amount,
                from: from?.map { $0.bech },
                to: to.bech,
                changeAddr: change?.bech,
                username: username,
                password: password
            )
            service.call(
                method: "platform.exportAVAX",
                params: params,
                ExportAVAXResponse.self,
                SerializableValue.self
            ) { res in
                cb(res
                    .mapError(AvalancheApiError.init)
                    .map { (TransactionID(cb58: $0.txID)!, try! Address(bech: $0.changeAddr)) })
            }
        case .account:
            fatalError("Not implemented")
        }
    }
    
    public struct GetTxParams: Encodable {
        public let txID: String
        public let encoding: AvalancheEncoding?
    }
    
    public struct GetTxResponse: Decodable {
        public let tx: String
        public let encoding: AvalancheEncoding
    }
    
    public func getTx(
        id: TransactionID,
        encoding: AvalancheEncoding?,
        _ cb: @escaping ApiCallback<SignedAvalancheTransaction>
    ) {
        let params = GetTxParams(
            txID: id.cb58(),
            encoding: encoding
        )
        service.call(
            method: "platform.getTx",
            params: params,
            GetTxResponse.self,
            SerializableValue.self
        ) { res in
            cb(res.mapError(AvalancheApiError.init).map { response in
                let transactionData: Data
                switch response.encoding {
                case .cb58: transactionData = Algos.Base58.from(cb58: response.tx)!
                case .hex: transactionData = Data(hex: response.tx)!
                }
                let decoder = ADecoder(
                    context: self.context,
                    data: transactionData
                )
                return try! decoder.decode()
            })
        }
    }
    
    public func getTransaction(id: TransactionID, result: @escaping ApiCallback<SignedAvalancheTransaction>) {
        getTx(id: id, encoding: .cb58, result)
    }
    
    public struct GetUTXOsParams: Encodable {
        public let addresses: [String]
        public let limit: UInt32?
        public let startIndex: UTXOIndex?
        public let sourceChain: String?
        public let encoding: AvalancheEncoding?
    }
    
    public struct GetUTXOsResponse: Decodable {
        public let numFetched: UInt32
        public let utxos: [String]
        public let endIndex: UTXOIndex
        public let encoding: AvalancheEncoding
    }
    
    public func getUTXOs(
        addresses: [Address],
        limit: UInt32? = nil,
        startIndex: UTXOIndex? = nil,
        sourceChain: BlockchainID? = nil,
        encoding: AvalancheEncoding? = nil,
        _ cb: @escaping ApiCallback<(
            fetched: UInt32,
            utxos: [UTXO],
            endIndex: UTXOIndex,
            encoding: AvalancheEncoding
        )>
    ) {
        let params = GetUTXOsParams(
            addresses: addresses.map { $0.bech },
            limit: limit,
            startIndex: startIndex,
            sourceChain: sourceChain?.cb58(),
            encoding: encoding
        )
        service.call(
            method: "platform.getUTXOs",
            params: params,
            GetUTXOsResponse.self,
            SerializableValue.self
        ) { res in
            cb(res
                .mapError(AvalancheApiError.init)
                .map {
                    return (
                        fetched: $0.numFetched,
                        utxos: $0.utxos.map {
                            let decoder = ADecoder(
                                context: self.context,
                                data: Algos.Base58.from(cb58: $0)!
                            )
                            return try! decoder.decode()
                        },
                        endIndex: $0.endIndex,
                        encoding: $0.encoding
                    )
                })
        }
    }

    public struct ImportAVAXParams: Encodable {
        public let from: [String]?
        public let to: String
        public let changeAddr: String?
        public let sourceChain: String
        public let username: String
        public let password: String
    }
    
    public struct ImportAVAXResponse: Decodable {
        public let txID: String
        public let changeAddr: String
    }
    
    public func importAVAX(
        from: [Address]? = nil,
        to: Address,
        change: Address? = nil,
        source: BlockchainID,
        credentials: AvalancheVmApiCredentials,
        _ cb: @escaping ApiCallback<(txID: TransactionID, change: Address)>
    ) {
        switch credentials {
        case .password(let username, let password):
            let params = ImportAVAXParams(
                from: from?.map { $0.bech },
                to: to.bech,
                changeAddr: change?.bech,
                sourceChain: source.cb58(),
                username: username,
                password: password
            )
            service.call(
                method: "platform.importAVAX",
                params: params,
                ImportAVAXResponse.self,
                SerializableValue.self
            ) { res in
                cb(res
                    .mapError(AvalancheApiError.init)
                    .map { (TransactionID(cb58: $0.txID)!, try! Address(bech: $0.changeAddr)) })
            }
        case .account:
            fatalError("Not implemented")
        }
    }
    
    public struct IssueTxParams: Encodable {
        public let tx: String
        public let encoding: AvalancheEncoding?
    }
    
    public struct IssueTxResponse: Decodable {
        public let txID: String
    }
    
    public func issueTx(
        tx: String,
        encoding: AvalancheEncoding? = nil,
        credentials: AvalancheVmApiCredentials,
        _ cb: @escaping ApiCallback<TransactionID>
    ) {
        switch credentials {
        case .password:
            let params = IssueTxParams(
                tx: tx,
                encoding: encoding
            )
            service.call(
                method: "platform.issueTx",
                params: params,
                IssueTxResponse.self,
                SerializableValue.self
            ) { res in
                cb(res
                    .mapError(AvalancheApiError.init)
                    .map { TransactionID(cb58: $0.txID)! })
            }
        case .account:
            fatalError("Not implemented")
        }
    }
}

extension AvalancheCore {
    public var pChain: AvalanchePChainApi {
        return try! self.getAPI()
    }
    
    public func pChain(networkID: NetworkID, hrp: String, info: AvalanchePChainApi.Info) -> AvalanchePChainApi {
        return self.createAPI(networkID: networkID, hrp: hrp, info: info)
    }
}
