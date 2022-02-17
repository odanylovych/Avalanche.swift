//
//  PChain.swift
//  
//
//  Created by Yehor Popovych on 10/4/20.
//

import Foundation
#if !COCOAPODS
import BigInt
import RPC
import Serializable
#endif

public class AvalanchePChainApi: AvalancheTransactionApi {
    public typealias Keychain = AvalanchePChainApiAddressManager
    
    public let networkID: NetworkID
    public let chainID: ChainID
    
    public let queue: DispatchQueue
    public let utxoProvider: AvalancheUtxoProvider
    public let signer: AvalancheSignatureProvider?
    public let encoderDecoderProvider: AvalancheEncoderDecoderProvider
    private let addressManager: AvalancheAddressManager?
    private let service: Client
    
    let blockchainIDs: (ChainID, @escaping ApiCallback<BlockchainID>) -> ()
    private let _txFee = CachedAsyncValue<UInt64, AvalancheApiError>()
    private let _creationTxFee = CachedAsyncValue<UInt64, AvalancheApiError>()
    private let _blockchainID: CachedAsyncValue<BlockchainID, AvalancheApiError>
    private let _avaxAssetID = CachedAsyncValue<AssetID, AvalancheApiError>()
    
    public var keychain: AvalanchePChainApiAddressManager? {
        addressManager.map {
            AvalanchePChainApiAddressManager(manager: $0, api: self)
        }
    }
    
    private var context: AvalancheDecoderContext {
        DefaultAvalancheDecoderContext(
            hrp: networkID.hrp,
            chainId: chainID.value,
            dynamicParser: PChainDynamicTypeRegistry.instance
        )
    }
    
    public required convenience init(avalanche: AvalancheCore, networkID: NetworkID) {
        self.init(avalanche: avalanche,
                  networkID: networkID,
                  chainID: .alias("P"),
                  vm: "platformvm")
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
        service = avalanche.connectionProvider.rpc(api: .pChain(chainID: chainID))
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
            this.getStakingAssetID { res in
                cb(res)
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
        nodeID: NodeID,
        startTime: Date,
        endTime: Date,
        stakeAmount: UInt64,
        reward: Address,
        from: [Address]? = nil,
        to: [Address]? = nil,
        change: Address? = nil,
        memo: Data = Data(),
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
            txAddDelegator(
                nodeID: nodeID,
                startTime: startTime,
                endTime: endTime,
                stakeAmount: stakeAmount,
                reward: reward,
                from: from,
                to: to,
                change: change,
                memo: memo,
                account: account,
                cb
            )
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
        to: [Address]? = nil,
        change: Address? = nil,
        memo: Data = Data(),
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
        case .account(let account):
            txAddValidator(
                nodeID: nodeID,
                startTime: startTime,
                endTime: endTime,
                stakeAmount: stakeAmount,
                reward: reward,
                delegationFeeRate: delegationFeeRate,
                from: from,
                to: to,
                change: change,
                memo: memo,
                account: account,
                cb
            )
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
        memo: Data = Data(),
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
        case .account(let account):
            txAddSubnetValidator(
                nodeID: nodeID,
                subnetID: subnetID,
                startTime: startTime,
                endTime: endTime,
                weight: weight,
                from: from,
                change: change,
                memo: memo,
                account: account,
                cb
            )
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
                guard let kc = self.keychain else {
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
        username: String,
        password: String,
        _ cb: @escaping ApiCallback<(txID: TransactionID, change: Address)>
    ) {
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
        memo: Data = Data(),
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
        case .account(let account):
            txCreateSubnet(
                controlKeys: controlKeys,
                threshold: threshold,
                from: from,
                change: change,
                memo: memo,
                account: account,
                cb
            )
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
        memo: Data = Data(),
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
        case .account(let account):
            txExportAVAX(
                to: to,
                amount: amount,
                from: from,
                change: change,
                memo: memo,
                account: account,
                cb
            )
        }
    }
    
    public struct GetBalanceUTXOID: Decodable {
        public let txID: String
        public let outputIndex: UInt32
    }
    
    public struct GetBalanceParams: Encodable {
        public let address: String
    }
    
    public struct GetBalanceResponse: Decodable {
        public let balance: String
        public let unlocked: String
        public let lockedStakeable: String
        public let lockedNotStakeable: String
        public let utxoIDs: [GetBalanceUTXOID]?
    }
    
    public func getBalance(
        address: Address,
        _ cb: @escaping ApiCallback<(
            balance: UInt64,
            unlocked: UInt64,
            lockedStakeable: UInt64,
            lockedNotStakeable: UInt64,
            utxoIDs: [UTXOID]
        )>
    ) {
        let params = GetBalanceParams(address: address.bech)
        service.call(
            method: "platform.getBalance",
            params: params,
            GetBalanceResponse.self,
            SerializableValue.self
        ) { res in
            cb(res.mapError(AvalancheApiError.init).map { response in (
                balance: UInt64(response.balance)!,
                unlocked: UInt64(response.unlocked)!,
                lockedStakeable: UInt64(response.lockedStakeable)!,
                lockedNotStakeable: UInt64(response.lockedNotStakeable)!,
                utxoIDs: response.utxoIDs != nil ? response.utxoIDs!.map { UTXOID(
                    transactionID: TransactionID(cb58: $0.txID)!,
                    utxoIndex: $0.outputIndex
                ) } : []
            ) })
        }
    }
    
    public struct GetStakingAssetIDParams: Encodable {
        public let subnetID: String?
    }
    
    public struct GetStakingAssetIDResponse: Decodable {
        public let assetID: String
    }
    
    public func getStakingAssetID(
        subnetID: String? = nil,
        _ cb: @escaping ApiCallback<AssetID>
    ) {
        let params = GetStakingAssetIDParams(
            subnetID: subnetID
        )
        service.call(
            method: "platform.getStakingAssetID",
            params: params,
            GetStakingAssetIDResponse.self,
            SerializableValue.self
        ) { res in
            cb(res.mapError(AvalancheApiError.init).map { AssetID(cb58: $0.assetID)! })
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
                let decoder = self.encoderDecoderProvider.decoder(
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
        public let numFetched: String
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
        memo: Data = Data(),
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
        case .account(let account):
            txImportAVAX(
                from: from,
                to: to,
                source: source,
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
            method: "platform.issueTx",
            params: params,
            IssueTxResponse.self,
            SerializableValue.self
        ) { res in
            cb(res
                .mapError(AvalancheApiError.init)
                .map { TransactionID(cb58: $0.txID)! })
        }
    }
}

extension AvalancheCore {
    public var pChain: AvalanchePChainApi {
        return try! self.getAPI()
    }
    
    public func pChain(networkID: NetworkID, chainID: ChainID, vm: String) -> AvalanchePChainApi {
        return AvalanchePChainApi(avalanche: self,
                                  networkID: networkID,
                                  chainID: chainID,
                                  vm: vm)
    }
}
