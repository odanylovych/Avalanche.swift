//
//  XChain.swift
//  
//
//  Created by Yehor Popovych on 10/14/20.
//

import Foundation
import BigInt
#if !COCOAPODS
import RPC
import Serializable
#endif

public class AvalancheXChainApiInfo: AvalancheBaseVMApiInfo {
    public let txFee: BigUInt
    public let creationTxFee: BigUInt
    
    public init(
        txFee: BigUInt, creationTxFee: BigUInt, blockchainID: BlockchainID,
        alias: String? = nil, vm: String = "avm"
    ) {
        self.txFee = txFee
        self.creationTxFee = creationTxFee
        super.init(blockchainID: blockchainID, alias: alias, vm: vm)
    }
    
    public var vmApiPath: String {
        return "/ext/vm/\(vm)"
    }
}

public class AvalancheXChainApi: AvalancheVMApi {
    public typealias Info = AvalancheXChainApiInfo
    public typealias Keychain = AvalancheXChainApiAddressManager
    
    private let addressManager: AvalancheAddressManager?
    private let utxoProvider: AvalancheUtxoProvider
    public let networkID: NetworkID
    public let hrp: String
    public let info: Info
    
    private let service: Client
    private let vmService: Client
    
    public var keychain: AvalancheXChainApiAddressManager? {
        addressManager.map {
            AvalancheXChainApiAddressManager(manager: $0, api: self)
        }
    }
    
    private var context: AvalancheDecoderContext {
        DefaultAvalancheDecoderContext(
            hrp: hrp,
            chainId: info.chainId,
            dynamicParser: XChainDynamicTypeRegistry.instance
        )
    }

    public required init(avalanche: AvalancheCore, networkID: NetworkID, hrp: String, info: Info) {
        self.networkID = networkID
        self.hrp = hrp
        self.info = info
        addressManager = avalanche.addressManager
        utxoProvider = avalanche.utxoProvider
        
        let settings = avalanche.settings
        
        self.service = JsonRpc(.http(url: avalanche.url(path: info.apiPath), session: settings.session, headers: settings.headers), queue: settings.queue, encoder: settings.encoder, decoder: settings.decoder)
        self.vmService = JsonRpc(.http(url: avalanche.url(path: info.vmApiPath), session: settings.session, headers: settings.headers), queue: settings.queue, encoder: settings.encoder, decoder: settings.decoder)
    }
    
    public struct InitialHolder: Encodable {
        public let address: String
        public let amount: UInt64
    }
    
    public struct CreateFixedCapAssetParams: Encodable {
        public let name: String
        public let symbol: String
        public let denomination: UInt32?
        public let initialHolders: [InitialHolder]
        public let from: [String]?
        public let changeAddr: String?
        public let username: String
        public let password: String
    }
    
    public struct CreateFixedCapAssetResponse: Decodable {
        public let assetID: String
        public let changeAddr: String
    }
    
    public func createFixedCapAsset(
        name: String,
        symbol: String,
        denomination: UInt32? = nil,
        initialHolders: [(address: Address, amount: UInt64)],
        from: [Address]? = nil,
        change: Address? = nil,
        memo: Data? = nil,
        credentials: AvalancheVmApiCredentials,
        _ cb: @escaping ApiCallback<(assetID: AssetID, change: Address)>
    ) {
        switch credentials {
        case .password(let username, let password):
            let params = CreateFixedCapAssetParams(
                name: name,
                symbol: symbol,
                denomination: denomination,
                initialHolders: initialHolders.map {
                    InitialHolder(address: $0.address.bech, amount: $0.amount)
                },
                from: from?.map { $0.bech },
                changeAddr: change?.bech,
                username: username,
                password: password
            )
            service.call(
                method: "avm.createFixedCapAsset",
                params: params,
                CreateFixedCapAssetResponse.self,
                SerializableValue.self
            ) { res in
                cb(res
                    .mapError(AvalancheApiError.init)
                    .map { (AssetID(cb58: $0.assetID)!, try! Address(bech: $0.changeAddr)) })
            }
        case .account:
            fatalError("Not implemented")
        }
    }
    
    public struct MintParams: Encodable {
        public let amount: UInt64
        public let assetID: String
        public let to: String
        public let from: [String]?
        public let changeAddr: String?
        public let username: String
        public let password: String
    }
    
    public struct MintResponse: Decodable {
        public let txID: String
        public let changeAddr: String
    }
    
    public func mint(
        amount: UInt64,
        assetID: AssetID,
        to: Address,
        from: [Address]? = nil,
        change: Address? = nil,
        credentials: AvalancheVmApiCredentials,
        _ cb: @escaping ApiCallback<(txID: TransactionID, change: Address)>
    ) {
        switch credentials {
        case .password(let username, let password):
            let params = MintParams(
                amount: amount,
                assetID: assetID.cb58(),
                to: to.bech,
                from: from?.map { $0.bech },
                changeAddr: change?.bech,
                username: username,
                password: password
            )
            service.call(
                method: "avm.mint",
                params: params,
                MintResponse.self,
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
    
    public struct MinterSet: Encodable {
        public let minters: [String]
        public let threshold: UInt32
    }
    
    public struct CreateVariableCapAssetParams: Encodable {
        public let name: String
        public let symbol: String
        public let denomination: UInt32?
        public let minterSets: [MinterSet]
        public let from: [String]?
        public let changeAddr: String?
        public let username: String
        public let password: String
    }
    
    public struct CreateVariableCapAssetResponse: Decodable {
        public let assetID: String
        public let changeAddr: String
    }

    public func createVariableCapAsset(
        name: String,
        symbol: String,
        denomination: UInt32? = nil,
        minterSets: [(minters: [Address], threshold: UInt32)],
        from: [Address]? = nil,
        change: Address? = nil,
        credentials: AvalancheVmApiCredentials,
        _ cb: @escaping ApiCallback<(assetID: AssetID, change: Address)>
    ) {
        switch credentials {
        case .password(let username, let password):
            let params = CreateVariableCapAssetParams(
                name: name,
                symbol: symbol,
                denomination: denomination,
                minterSets: minterSets.map {
                    MinterSet(minters: $0.minters.map { $0.bech }, threshold: $0.threshold)
                },
                from: from?.map { $0.bech },
                changeAddr: change?.bech,
                username: username,
                password: password
            )
            service.call(
                method: "avm.createVariableCapAsset",
                params: params,
                CreateVariableCapAssetResponse.self,
                SerializableValue.self
            ) { res in
                cb(res
                    .mapError(AvalancheApiError.init)
                    .map { (AssetID(cb58: $0.assetID)!, try! Address(bech: $0.changeAddr)) })
            }
        case .account:
            fatalError("Not implemented")
        }
    }

    public struct CreateNFTAssetParams: Encodable {
        public let name: String
        public let symbol: String
        public let minterSets: [MinterSet]
        public let from: [String]?
        public let changeAddr: String?
        public let username: String
        public let password: String
    }
    
    public struct CreateNFTAssetResponse: Decodable {
        public let assetID: String
        public let changeAddr: String
    }

    public func createNFTAsset(
        name: String,
        symbol: String,
        minterSets: [(minters: [Address], threshold: UInt32)],
        from: [Address]? = nil,
        change: Address? = nil,
        credentials: AvalancheVmApiCredentials,
        _ cb: @escaping ApiCallback<(assetID: AssetID, change: Address)>
    ) {
        switch credentials {
        case .password(let username, let password):
            let params = CreateNFTAssetParams(
                name: name,
                symbol: symbol,
                minterSets: minterSets.map {
                    MinterSet(minters: $0.minters.map { $0.bech }, threshold: $0.threshold)
                },
                from: from?.map { $0.bech },
                changeAddr: change?.bech,
                username: username,
                password: password
            )
            service.call(
                method: "avm.createNFTAsset",
                params: params,
                CreateNFTAssetResponse.self,
                SerializableValue.self
            ) { res in
                cb(res
                    .mapError(AvalancheApiError.init)
                    .map { (AssetID(cb58: $0.assetID)!, try! Address(bech: $0.changeAddr)) })
            }
        case .account:
            fatalError("Not implemented")
        }
    }
    
    public struct MintNFTParams: Encodable {
        public let assetID: String
        public let payload: String
        public let to: String
        public let encoding: AvalancheEncoding?
        public let from: [String]?
        public let changeAddr: String?
        public let username: String
        public let password: String
    }
    
    public struct MintNFTResponse: Decodable {
        public let txID: String
        public let changeAddr: String
    }
    
    public func mintNFT(
        assetID: AssetID,
        payload: String,
        to: Address,
        encoding: AvalancheEncoding? = nil,
        from: [Address]? = nil,
        change: Address? = nil,
        credentials: AvalancheVmApiCredentials,
        _ cb: @escaping ApiCallback<(txID: TransactionID, change: Address)>
    ) {
        switch credentials {
        case .password(let username, let password):
            let params = MintNFTParams(
                assetID: assetID.cb58(),
                payload: payload,
                to: to.bech,
                encoding: encoding,
                from: from?.map { $0.bech },
                changeAddr: change?.bech,
                username: username,
                password: password
            )
            service.call(
                method: "avm.mintNFT",
                params: params,
                MintNFTResponse.self,
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
    
    public struct ExportParams: Encodable {
        public let to: String
        public let amount: UInt64
        public let assetID: String
        public let from: [String]?
        public let changeAddr: String?
        public let username: String
        public let password: String
    }
    
    public struct ExportResponse: Decodable {
        public let txID: String
        public let changeAddr: String
    }
    
    public func export(
        to: Address,
        amount: UInt64,
        assetID: AssetID,
        from: [Address]? = nil,
        change: Address? = nil,
        credentials: AvalancheVmApiCredentials,
        _ cb: @escaping ApiCallback<(txID: TransactionID, change: Address)>
    ) {
        switch credentials {
        case .password(let username, let password):
            let params = ExportParams(
                to: to.bech,
                amount: amount,
                assetID: assetID.cb58(),
                from: from?.map { $0.bech },
                changeAddr: change?.bech,
                username: username,
                password: password
            )
            service.call(
                method: "avm.export",
                params: params,
                ExportResponse.self,
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
        public let to: String
        public let amount: UInt64
        public let from: [String]?
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
                to: to.bech,
                amount: amount,
                from: from?.map { $0.bech },
                changeAddr: change?.bech,
                username: username,
                password: password
            )
            service.call(
                method: "avm.exportAVAX",
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
    
    public struct GetAllBalancesParams: Encodable {
        public let address: String
    }
    
    public struct Balance: Decodable {
        public let asset: String
        public let balance: Int
    }
    
    public struct GetAllBalancesResponse: Decodable {
        public let balances: [Balance]
    }
    
    public func getAllBalances(
        address: Address,
        _ cb: @escaping ApiCallback<[(asset: AssetID, balance: Int)]>
    ) {
        let params = GetAllBalancesParams(
            address: address.bech
        )
        service.call(
            method: "avm.getAllBalances",
            params: params,
            GetAllBalancesResponse.self,
            SerializableValue.self
        ) { res in
            cb(res.mapError(AvalancheApiError.init).map { response in
                response.balances.map { (asset: AssetID(cb58: $0.asset)!, balance: $0.balance) }
            })
        }
    }
    
    public enum GetTransactionEncoding: String, Codable {
        case cb58 = "cb58"
        case hex = "hex"
        case json = "json"
    }
    
    public struct GetTxParams: Encodable {
        public let txID: String
        public let encoding: GetTransactionEncoding?
    }
    
    public struct GetTxResponse: Decodable {
        public let tx: String
        public let encoding: GetTransactionEncoding
    }
    
    public func getTx(
        id: TransactionID,
        encoding: GetTransactionEncoding?,
        _ cb: @escaping ApiCallback<SignedAvalancheTransaction>
    ) {
        let params = GetTxParams(
            txID: id.cb58(),
            encoding: encoding
        )
        service.call(
            method: "avm.getTx",
            params: params,
            GetTxResponse.self,
            SerializableValue.self
        ) { res in
            cb(res.mapError(AvalancheApiError.init).map { response in
                let transactionData: Data
                switch response.encoding {
                case .cb58: transactionData = Algos.Base58.from(cb58: response.tx)!
                case .hex: transactionData = Data(hex: response.tx)!
                case .json:
                    // TODO: handle error
                    fatalError("Not implemented")
                }
                let decoder = ADecoder(
                    context: self.context,
                    data: transactionData
                )
                return try! decoder.decode()
            })
        }
    }
    
    public func getTransaction(
        id: TransactionID,
        result: @escaping ApiCallback<SignedAvalancheTransaction>
    ) {
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
        public let sourceChain: String?
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
            method: "avm.getUTXOs",
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
                            return try! UTXO(from: decoder)
                        },
                        endIndex: $0.endIndex,
                        encoding: $0.encoding
                    )
                })
        }
    }

    public struct ImportParams: Encodable {
        public let to: String
        public let sourceChain: String
        public let username: String
        public let password: String
    }
    
    public struct ImportResponse: Decodable {
        public let txID: String
    }
    
    public func `import`(
        to: Address,
        source: BlockchainID,
        credentials: AvalancheVmApiCredentials,
        _ cb: @escaping ApiCallback<TransactionID>
    ) {
        switch credentials {
        case .password(let username, let password):
            let params = ImportParams(
                to: to.bech,
                sourceChain: source.cb58(),
                username: username,
                password: password
            )
            service.call(
                method: "avm.import",
                params: params,
                ImportResponse.self,
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
    
    public struct ImportAVAXParams: Encodable {
        public let to: String
        public let sourceChain: String
        public let username: String
        public let password: String
    }
    
    public struct ImportAVAXResponse: Decodable {
        public let txID: String
    }
    
    public func importAVAX(
        to: Address,
        source: BlockchainID,
        credentials: AvalancheVmApiCredentials,
        _ cb: @escaping ApiCallback<TransactionID>
    ) {
        switch credentials {
        case .password(let username, let password):
            let params = ImportAVAXParams(
                to: to.bech,
                sourceChain: source.cb58(),
                username: username,
                password: password
            )
            service.call(
                method: "avm.importAVAX",
                params: params,
                ImportAVAXResponse.self,
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
                method: "avm.issueTx",
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
    
    public struct SendParams: Encodable {
        public let amount: UInt64
        public let assetID: String
        public let to: String
        public let memo: String?
        public let from: [String]?
        public let changeAddr: String?
        public let username: String
        public let password: String
    }
    
    public struct SendResponse: Decodable {
        public let txID: String
        public let changeAddr: String
    }
    
    public func send(
        amount: UInt64,
        assetID: AssetID,
        to: Address,
        memo: String? = nil,
        from: [Address]? = nil,
        change: Address? = nil,
        credentials: AvalancheVmApiCredentials,
        _ cb: @escaping ApiCallback<(txID: TransactionID, change: Address)>
    ) {
        switch credentials {
        case .password(let username, let password):
            let params = SendParams(
                amount: amount,
                assetID: assetID.cb58(),
                to: to.bech,
                memo: memo,
                from: from?.map { $0.bech },
                changeAddr: change?.bech,
                username: username,
                password: password
            )
            service.call(
                method: "avm.send",
                params: params,
                SendResponse.self,
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
    
    public struct SendMultipleOutput: Encodable {
        public let assetID: String
        public let amount: UInt64
        public let to: String
    }
    
    public struct SendMultipleParams: Encodable {
        public let outputs: [SendMultipleOutput]
        public let from: [String]?
        public let changeAddr: String?
        public let memo: String?
        public let username: String
        public let password: String
    }
    
    public struct SendMultipleResponse: Decodable {
        public let txID: String
        public let changeAddr: String
    }
    
    public func sendMultiple(
        outputs: [(assetID: AssetID, amount: UInt64, to: Address)],
        from: [Address]? = nil,
        change: Address? = nil,
        memo: String? = nil,
        credentials: AvalancheVmApiCredentials,
        _ cb: @escaping ApiCallback<(txID: TransactionID, change: Address)>
    ) {
        switch credentials {
        case .password(let username, let password):
            let params = SendMultipleParams(
                outputs: outputs.map {
                    SendMultipleOutput(assetID: $0.assetID.cb58(), amount: $0.amount, to: $0.to.bech)
                },
                from: from?.map { $0.bech },
                changeAddr: change?.bech,
                memo: memo,
                username: username,
                password: password
            )
            service.call(
                method: "avm.sendMultiple",
                params: params,
                SendMultipleResponse.self,
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
    
    public struct SendNFTParams: Encodable {
        public let assetID: String
        public let groupID: UInt32
        public let to: String
        public let from: [String]?
        public let changeAddr: String?
        public let username: String
        public let password: String
    }
    
    public struct SendNFTResponse: Decodable {
        public let txID: String
    }
    
    public func sendNFT(
        assetID: AssetID,
        groupID: UInt32,
        to: Address,
        from: [Address]? = nil,
        change: Address? = nil,
        credentials: AvalancheVmApiCredentials,
        _ cb: @escaping ApiCallback<TransactionID>
    ) {
        switch credentials {
        case .password(let username, let password):
            let params = SendNFTParams(
                assetID: assetID.cb58(),
                groupID: groupID,
                to: to.bech,
                from: from?.map { $0.bech },
                changeAddr: change?.bech,
                username: username,
                password: password
            )
            service.call(
                method: "avm.sendNFT",
                params: params,
                SendNFTResponse.self,
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
    public var xChain: AvalancheXChainApi {
        return try! self.getAPI()
    }
    
    public func xChain(networkID: NetworkID, hrp: String, info: AvalancheXChainApi.Info) -> AvalancheXChainApi {
        return self.createAPI(networkID: networkID, hrp: hrp, info: info)
    }
}
