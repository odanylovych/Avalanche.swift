//
//  XChain.swift
//  
//
//  Created by Yehor Popovych on 10/14/20.
//

import Foundation
import BigInt
import JsonRPC
import Serializable

public class AvalancheXChainApi: AvalancheTransactionApi {
    public typealias Keychain = AvalancheXChainApiAddressManager
    
    public let networkID: NetworkID
    public let chainID: ChainID
    
    public let queue: DispatchQueue
    public let utxoProvider: AvalancheUtxoProvider
    public let signer: AvalancheSignatureProvider?
    public let encoderDecoderProvider: AvalancheEncoderDecoderProvider
    private let addressManager: AvalancheAddressManager?
    private let service: Client
    private let vmService: Client
    
    let blockchainIDs: (ChainID, @escaping ApiCallback<BlockchainID>) -> ()
    private let _txFee = CachedAsyncValue<UInt64, AvalancheApiError>()
    private let _creationTxFee = CachedAsyncValue<UInt64, AvalancheApiError>()
    private let _blockchainID: CachedAsyncValue<BlockchainID, AvalancheApiError>
    private let _avaxAssetID = CachedAsyncValue<AssetID, AvalancheApiError>()
    
    public var keychain: AvalancheXChainApiAddressManager? {
        addressManager.map {
            AvalancheXChainApiAddressManager(manager: $0, api: self)
        }
    }
    
    private var context: AvalancheDecoderContext {
        DefaultAvalancheDecoderContext(
            hrp: networkID.hrp,
            chainId: chainID.value,
            dynamicParser: XChainDynamicTypeRegistry.instance
        )
    }
    
    public required convenience init(avalanche: AvalancheCore, networkID: NetworkID, chainID: ChainID) {
        self.init(avalanche: avalanche,
                  networkID: networkID,
                  chainID: chainID,
                  vm: "avm")
    }
    
    public required init(avalanche: AvalancheCore,
                         networkID: NetworkID,
                         chainID: ChainID,
                         vm: String) {
        self.networkID = networkID
        self.chainID = chainID
        queue = avalanche.settings.queue
        utxoProvider = avalanche.settings.utxoProvider
        signer = avalanche.signatureProvider
        encoderDecoderProvider = avalanche.settings.encoderDecoderProvider
        addressManager = avalanche.settings.addressManagerProvider.manager(ava: avalanche)
        service = avalanche.connectionProvider.rpc(api: .xChain(chainID: chainID))
        vmService = avalanche.connectionProvider.rpc(api: .xChainVM(vm: vm))
        blockchainIDs = { chainID, cb in
            switch chainID {
            case .alias(let alias):
                avalanche.info.getBlockchainID(alias: alias) { res in
                    cb(res)
                }
            case .blockchainID(let blockchainID):
                cb(.success(blockchainID))
            }
        }
        _txFee.getter = { cb in
            avalanche.info.getTxFee { res in
                cb(res.map { $0.txFee })
            }
        }
        _creationTxFee.getter = { cb in
            avalanche.info.getTxFee { res in
                cb(res.map { $0.creationTxFee })
            }
        }
        switch chainID {
        case .alias(let alias):
            _blockchainID = CachedAsyncValue<BlockchainID, AvalancheApiError>() { cb in
                avalanche.info.getBlockchainID(alias: alias) { res in
                    cb(res)
                }
            }
        case .blockchainID(let blockchainID):
            _blockchainID = CachedAsyncValue<BlockchainID, AvalancheApiError>(blockchainID)
        }
        _avaxAssetID.getter = { [weak self] cb in
            guard let this = self else {
                cb(.failure(.nilAvalancheApi))
                return
            }
            this.getAssetDescription(assetID: AvalancheConstants.avaxAssetAlias) { res in
                cb(res.map { $0.0 })
            }
        }
    }
    
    public func getTxFee(_ cb: @escaping ApiCallback<UInt64>) {
        _txFee.get(cb)
    }
    
    public func getCreationTxFee(_ cb: @escaping ApiCallback<UInt64>) {
        _creationTxFee.get(cb)
    }
    
    public func getBlockchainID(_ cb: @escaping ApiCallback<BlockchainID>) {
        _blockchainID.get(cb)
    }
    
    public func getAvaxAssetID(_ cb: @escaping ApiCallback<AssetID>) {
        _avaxAssetID.get(cb)
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
        public let encoding: ApiDataEncoding?
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
                encoding: .hex,
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
    
    public struct GetTxParams: Encodable {
        public let txID: String
        public let encoding: GetTxEncoding?
    }
    
    public struct GetTxResponse: Decodable {
        public let tx: String
        public let encoding: GetTxEncoding
    }
    
    public func getTx(
        id: TransactionID,
        _ cb: @escaping ApiCallback<SignedAvalancheTransaction>
    ) {
        let params = GetTxParams(
            txID: id.cb58(),
            encoding: .hex
        )
        service.call(
            method: "avm.getTx",
            params: params,
            GetTxResponse.self,
            SerializableValue.self
        ) { res in
            switch res {
            case .success(let response):
                guard case .hex = response.encoding else {
                    self.handleError(.unsupportedEncoding(encoding: response.encoding.rawValue), cb)
                    return
                }
                let transactionData = Data(hex: response.tx)!
                let decoder = self.encoderDecoderProvider.decoder(
                    context: self.context,
                    data: transactionData
                )
                cb(.success(try! decoder.decode()))
            case .failure(let error):
                self.handleError(.init(request: error), cb)
            }
        }
    }
    
    public func getTransaction(
        id: TransactionID,
        result: @escaping ApiCallback<SignedAvalancheTransaction>
    ) {
        getTx(id: id, result)
    }
    
    public struct GetUTXOsParams: Encodable {
        public let addresses: [String]
        public let limit: UInt32?
        public let startIndex: UTXOIndex?
        public let sourceChain: String?
        public let encoding: ApiDataEncoding?
    }
    
    public struct GetUTXOsResponse: Decodable {
        public let numFetched: String
        public let utxos: [String]
        public let endIndex: UTXOIndex
        public let sourceChain: String?
        public let encoding: ApiDataEncoding
    }
    
    public func getUTXOs(
        addresses: [Address],
        limit: UInt32? = nil,
        startIndex: UTXOIndex? = nil,
        sourceChain: BlockchainID? = nil,
        _ cb: @escaping ApiCallback<(
            fetched: UInt32,
            utxos: [UTXO],
            endIndex: UTXOIndex
        )>
    ) {
        let params = GetUTXOsParams(
            addresses: addresses.map { $0.bech },
            limit: limit,
            startIndex: startIndex,
            sourceChain: sourceChain?.cb58(),
            encoding: .hex
        )
        service.call(
            method: "avm.getUTXOs",
            params: params,
            GetUTXOsResponse.self,
            SerializableValue.self
        ) { res in
            switch res {
            case .success(let response):
                guard case .hex = response.encoding else {
                    self.handleError(.unsupportedEncoding(encoding: response.encoding.rawValue), cb)
                    return
                }
                cb(.success((
                    fetched: UInt32(response.numFetched)!,
                    utxos: response.utxos.map {
                        let decoder = self.encoderDecoderProvider.decoder(
                            context: self.context,
                            data: Data(hex: $0)!
                        )
                        return try! decoder.decode()
                    },
                    endIndex: response.endIndex
                )))
            case .failure(let error):
                self.handleError(.init(request: error), cb)
            }
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
    
    public func `import`<A: AvalancheTransactionApi>(
        to: Address,
        source api: A,
        memo: Data = Data(),
        credentials: AvalancheVmApiCredentials,
        _ cb: @escaping ApiCallback<TransactionID>
    ) {
        switch credentials {
        case .password(let username, let password):
            let params = ImportParams(
                to: to.bech,
                sourceChain: api.chainID.value,
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
                source: api,
                memo: memo,
                account: account,
                cb
            )
        }
    }
    
    public struct IssueTxParams: Encodable {
        public let tx: String
        public let encoding: ApiDataEncoding?
    }
    
    public struct IssueTxResponse: Decodable {
        public let txID: String
    }
    
    public func issueTx(
        tx: Data,
        _ cb: @escaping ApiCallback<TransactionID>
    ) {
        let params = IssueTxParams(
            tx: tx.hex(),
            encoding: .hex
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
        return try! self.getAPI(chainID: .alias("X"))
    }
    
    public func xChain(chainID: ChainID) -> AvalancheXChainApi {
        return try! self.getAPI(chainID: chainID)
    }
    
    public func xChain(networkID: NetworkID, chainID: ChainID, vm: String) -> AvalancheXChainApi {
        return AvalancheXChainApi(avalanche: self,
                                  networkID: networkID,
                                  chainID: chainID,
                                  vm: vm)
    }
}
