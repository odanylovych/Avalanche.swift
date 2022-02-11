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
    
    override public var connectionType: ApiConnectionType {
        .xChain(alias: alias, blockchainID: blockchainID)
    }
    
    public var vmConnectionType: ApiConnectionType {
        .xChainVM(vm: vm)
    }
}

public class AvalancheXChainApi: AvalancheTransactionApi {
    public typealias Info = AvalancheXChainApiInfo
    public typealias Keychain = AvalancheXChainApiAddressManager
    
    public let queue: DispatchQueue
    private let addressManager: AvalancheAddressManager?
    public let utxoProvider: AvalancheUtxoProvider
    public let signer: AvalancheSignatureProvider?
    public let encoderDecoderProvider: AvalancheEncoderDecoderProvider
    public let chainIDApiInfos: (String) -> AvalancheVMApiInfo
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
        let addressManagerProvider = avalanche.settings.addressManagerProvider
        addressManager = addressManagerProvider.manager(ava: avalanche)
        utxoProvider = avalanche.settings.utxoProvider
        signer = avalanche.signatureProvider
        encoderDecoderProvider = avalanche.settings.encoderDecoderProvider
        chainIDApiInfos = {
            [
                avalanche.pChain.info.alias!: avalanche.pChain.info,
                avalanche.cChain.info.alias!: avalanche.cChain.info
            ][$0]!
        }
        
        let settings = avalanche.settings
        queue = settings.queue
        
        let connectionProvider = avalanche.connectionProvider
        service = connectionProvider.rpc(api: info.connectionType)
        vmService = connectionProvider.rpc(api: info.vmConnectionType)
    }
    
    public func getAvaxAssetID(_ cb: @escaping ApiCallback<AssetID>) {
        getAssetDescription(assetID: AvalancheConstants.avaxAssetAlias) { res in
            cb(res.map { avaxAssetID, _, _, _ in
                avaxAssetID
            })
        }
    }
    
    public struct InitialHolder: Encodable {
        public let address: String
        public let amount: UInt64
    }
    
    public struct CreateFixedCapAssetParams: Encodable {
        public let name: String
        public let symbol: String
        public let denomination: UInt8?
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
        denomination: UInt8? = nil,
        initialHolders: [(address: Address, amount: UInt64)],
        from: [Address]? = nil,
        change: Address? = nil,
        memo: Data = Data(),
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
        case .account(let account):
            txCreateFixedCapAsset(
                name: name,
                symbol: symbol,
                denomination: denomination,
                initialHolders: initialHolders,
                from: from,
                change: change,
                memo: memo,
                account: account,
                cb
            )
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
        memo: Data = Data(),
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
        case .account(let account):
            txMint(
                amount: amount,
                assetID: assetID,
                to: to,
                from: from,
                change: change,
                memo: memo,
                account: account,
                cb
            )
        }
    }
    
    public struct MinterSet: Encodable {
        public let minters: [String]
        public let threshold: UInt32
    }
    
    public struct CreateVariableCapAssetParams: Encodable {
        public let name: String
        public let symbol: String
        public let denomination: UInt8?
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
        denomination: UInt8? = nil,
        minterSets: [(minters: [Address], threshold: UInt32)],
        from: [Address]? = nil,
        change: Address? = nil,
        memo: Data = Data(),
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
        case .account(let account):
            txCreateVariableCapAsset(
                name: name,
                symbol: symbol,
                denomination: denomination,
                minterSets: minterSets,
                from: from,
                change: change,
                memo: memo,
                account: account,
                cb
            )
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
        memo: Data = Data(),
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
        case .account(let account):
            txCreateNFTAsset(
                name: name,
                symbol: symbol,
                minterSets: minterSets,
                from: from,
                change: change,
                memo: memo,
                account: account,
                cb
            )
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
        memo: Data = Data(),
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
        case .account(let account):
            txMintNFT(
                assetID: assetID,
                payload: payload,
                to: to,
                encoding: encoding,
                from: from,
                change: change,
                memo: memo,
                account: account,
                cb
            )
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
        memo: Data = Data(),
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
        case .account(let account):
            txExport(
                to: to,
                amount: amount,
                assetID: assetID,
                from: from,
                change: change,
                memo: memo,
                account: account,
                cb
            )
        }
    }
    
    public struct GetAllBalancesParams: Encodable {
        public let address: String
    }
    
    public struct Balance: Decodable {
        public let asset: String
        public let balance: String
    }
    
    public struct GetAllBalancesResponse: Decodable {
        public let balances: [Balance]
    }
    
    public func getAllBalances(
        address: Address,
        _ cb: @escaping ApiCallback<[(asset: String, balance: UInt64)]>
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
                response.balances.map { (asset: $0.asset, balance: UInt64($0.balance)!) }
            })
        }
    }
    
    public struct GetAssetDescriptionParams: Encodable {
        public let assetID: String
    }
    
    public struct GetAssetDescriptionResponse: Decodable {
        public let assetID: String
        public let name: String
        public let symbol: String
        public let denomination: String
    }
    
    public func getAssetDescription(
        assetID: String,
        _ cb: @escaping ApiCallback<(
            assetID: AssetID,
            name: String,
            symbol: String,
            denomination: UInt32
        )>
    ) {
        let params = GetAssetDescriptionParams(
            assetID: assetID
        )
        service.call(
            method: "avm.getAssetDescription",
            params: params,
            GetAssetDescriptionResponse.self,
            SerializableValue.self
        ) { res in
            cb(res.mapError(AvalancheApiError.init).map {
                (
                    assetID: AssetID(cb58: $0.assetID)!,
                    name: $0.name,
                    symbol: $0.symbol,
                    denomination: UInt32($0.denomination)!
                )
            })
        }
    }
    
    public struct GetAddressTxsParams: Encodable {
        public let address: String
        public let cursor: UInt64?
        public let assetID: String
        public let pageSize: UInt64?
    }
    
    public struct GetAddressTxsResponse: Decodable {
        public let txIDs: [String]
        public let cursor: String
    }
    
    public func getAddressTxs(
        address: Address,
        cursor: UInt64? = nil,
        assetID: AssetID,
        pageSize: UInt64? = nil,
        _ cb: @escaping ApiCallback<(txIDs: [TransactionID], cursor: UInt64)>
    ) {
        let params = GetAddressTxsParams(
            address: address.bech,
            cursor: cursor,
            assetID: assetID.cb58(),
            pageSize: pageSize
        )
        service.call(
            method: "avm.getAddressTxs",
            params: params,
            GetAddressTxsResponse.self,
            SerializableValue.self
        ) { res in
            cb(res.mapError(AvalancheApiError.init).map { response in
                (
                    txIDs: response.txIDs.map { TransactionID(cb58: $0)! },
                    cursor: UInt64(response.cursor)!
                )
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
            switch res {
            case .success(let response):
                switch response.encoding {
                case .cb58:
                    let transactionData = Algos.Base58.from(cb58: response.tx)!
                    let decoder = self.encoderDecoderProvider.decoder(
                        context: self.context,
                        data: transactionData
                    )
                    cb(.success(try! decoder.decode()))
                case .hex:
                    let transactionData = Data(hex: response.tx)!
                    let decoder = self.encoderDecoderProvider.decoder(
                        context: self.context,
                        data: transactionData
                    )
                    cb(.success(try! decoder.decode()))
                case .json:
                    self.handleError(.unsupportedEncoding(encoding: "json"), cb)
                }
            case .failure(let error):
                self.handleError(.init(request: error), cb)
            }
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
        public let numFetched: String
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
                        fetched: UInt32($0.numFetched)!,
                        utxos: $0.utxos.map {
                            let decoder = self.encoderDecoderProvider.decoder(
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
        sourceChain: BlockchainID,
        memo: Data = Data(),
        credentials: AvalancheVmApiCredentials,
        _ cb: @escaping ApiCallback<TransactionID>
    ) {
        switch credentials {
        case .password(let username, let password):
            let params = ImportParams(
                to: to.bech,
                sourceChain: sourceChain.cb58(),
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
        case .account(let account):
            txImport(
                to: to,
                sourceChain: sourceChain,
                memo: memo,
                account: account,
                cb
            )
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
        _ cb: @escaping ApiCallback<TransactionID>
    ) {
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
        avax: UInt64,
        to: Address,
        memo: String? = nil,
        from: [Address]? = nil,
        change: Address? = nil,
        credentials: AvalancheVmApiCredentials,
        _ cb: @escaping ApiCallback<(txID: TransactionID, change: Address)>
    ) {
        getAvaxAssetID { res in
            switch res {
            case .success(let assetID):
                self.send(amount: avax,
                     assetID: assetID,
                     to: to,
                     memo: memo,
                     from: from,
                     change: change,
                     credentials: credentials, cb)
            case .failure(let error):
                self.handleError(error, cb)
            }
        }
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
        case .account(let account):
            txSend(
                amount: amount,
                assetID: assetID,
                to: to,
                memo: memo,
                from: from,
                change: change,
                account: account,
                cb
            )
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
        case .account(let account):
            txSendMultiple(
                outputs: outputs,
                from: from,
                change: change,
                memo: memo,
                account: account,
                cb
            )
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
        memo: Data = Data(),
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
        case .account(let account):
            txSendNFT(
                assetID: assetID,
                groupID: groupID,
                to: to,
                from: from,
                change: change,
                memo: memo,
                account: account,
                cb
            )
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
