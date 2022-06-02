//
//  CChain.swift
//  
//
//  Created by Yehor Popovych on 10/14/20.
//

import Foundation
import BigInt
import web3swift
import JsonRPC
import Serializable

public enum CChainApiCredentials {
    case password(username: String, password: String)
    case account(EthAccount)
}

public class AvalancheCChainApi: AvalancheTransactionApi {
    public typealias Keychain = AvalancheCChainApiAddressManager
    
    public let networkID: NetworkID
    public let chainID: ChainID
    
    public let queue: DispatchQueue
    public let utxoProvider: AvalancheUtxoProvider
    public let signer: AvalancheSignatureProvider?
    public let encoderDecoderProvider: AvalancheEncoderDecoderProvider
    private let addressManager: AvalancheCChainAddressManager?
    private let service: Client
    private let vmService: Client
    
    let blockchainIDs: (ChainID, @escaping ApiCallback<BlockchainID>) -> ()
    private let _web3 = CachedAsyncValue<web3, AvalancheApiError>()
    private let _txFee = CachedAsyncValue<UInt64, AvalancheApiError>()
    private let _blockchainID: CachedAsyncValue<BlockchainID, AvalancheApiError>
    private let _avaxAssetID = CachedAsyncValue<AssetID, AvalancheApiError>()
    private let _ethChainID = CachedAsyncValue<BigUInt, AvalancheApiError>()
    
    public var keychain: AvalancheCChainApiAddressManager? {
        addressManager.map {
            AvalancheCChainApiAddressManager(manager: $0, api: self)
        }
    }
    
    private var context: AvalancheDecoderContext {
        DefaultAvalancheDecoderContext(
            hrp: networkID.hrp,
            chainId: chainID.value,
            dynamicParser: CChainDynamicTypeRegistry.instance
        )
    }
    
    public required convenience init(avalanche: AvalancheCore, networkID: NetworkID, chainID: ChainID) {
        self.init(avalanche: avalanche,
                  networkID: networkID,
                  chainID: chainID,
                  vm: "evm")
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
        let addressManager = avalanche.settings.addressManagerProvider.manager(ava: avalanche)
        self.addressManager = addressManager.map(AvalancheCChainAddressManager.init)
        service = avalanche.connectionProvider.rpc(api: .cChain(chainID: chainID))
        if let subscribable = avalanche.connectionProvider.subscribableRPC(api: .cChainVM(chainID: chainID)) {
            vmService = subscribable
        } else {
            vmService = avalanche.connectionProvider.rpc(api: .cChainVM(chainID: chainID))
        }
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
        _web3.getter = { [weak self] cb in
            guard let this = self else {
                cb(.failure(.nilAvalancheApi))
                return
            }
            this.getEthChainID { res in
                cb(res.map { chainID in
                    let url = URL(string: "http://notused")!
                    let network: Networks = .Custom(networkID: chainID)
                    let web3Provider: Web3Provider
                    if let vmService = this.vmService as? Subscribable {
                        web3Provider = Web3SubscriptionNetworkProvider(network: network, url: url, service: vmService)
                    } else {
                        web3Provider = Web3NetworkProvider(network: network, url: url, service: this.vmService)
                    }
                    var web3Signer: SignatureProvider? = nil
                    if let signer = this.signer, let manager = addressManager {
                        web3Signer = Web3SignatureProvider(chainID: chainID, signer: signer, manager: manager)
                    }
                    return web3swift.web3(provider: web3Provider, signer: web3Signer)
                })
            }
        }
        _txFee.getter = { cb in
            avalanche.info.getTxFee { res in
                cb(res.map { $0.txFee })
            }
        }
        _avaxAssetID.getter = { cb in
            avalanche.xChain.getAssetDescription(assetID: AvalancheConstants.avaxAssetAlias) { res in
                cb(res.map { $0.0 })
            }
        }
        _ethChainID.getter = { [weak self] cb in
            guard let this = self else {
                cb(.failure(.nilAvalancheApi))
                return
            }
            this.ethChainID { res in
                cb(res)
            }
        }
    }
    
    deinit {
        if let vmService = vmService as? Connectable {
            vmService.disconnect()
        }
    }
    
    public func getTxFee(_ cb: @escaping ApiCallback<UInt64>) {
        _txFee.get(cb)
    }
    
    public func getBlockchainID(_ cb: @escaping ApiCallback<BlockchainID>) {
        _blockchainID.get(cb)
    }
    
    public func getAvaxAssetID(_ cb: @escaping ApiCallback<AssetID>) {
        _avaxAssetID.get(cb)
    }
    
    public func getEthChainID(_ cb: @escaping ApiCallback<BigUInt>) {
        _ethChainID.get(cb)
    }
    
    public func getWeb3(_ cb: @escaping ApiCallback<web3>) {
        _web3.get(cb)
    }
    
    public func getEth(_ cb: @escaping ApiCallback<web3.Eth>) {
        getWeb3 { res in
            cb(res.map { $0.eth })
        }
    }
    
    public func getPersonal(_ cb: @escaping ApiCallback<web3.Personal>) {
        getWeb3 { res in
            cb(res.map { $0.personal })
        }
    }
    
    public func getTxPool(_ cb: @escaping ApiCallback<web3.TxPool>) {
        getWeb3 { res in
            cb(res.map { $0.txPool })
        }
    }
    
    public func ethChainID(_ cb: @escaping ApiCallback<BigUInt>) {
        vmService.call(
            method: "eth_chainId",
            params: Nil.nil,
            String.self,
            SerializableValue.self
        ) { res in
            cb(res.mapError(AvalancheApiError.init).map {
                BigUInt($0.dropFirst(2), radix: 16)!
            })
        }
    }
    
    public struct GetAtomicTxParams: Encodable {
        public let txID: String
        public let encoding: AvalancheEncoding?
    }
    
    public struct GetAtomicTxResponse: Decodable {
        public let tx: String
        public let encoding: AvalancheEncoding
        public let blockHeight: String
    }
    
    public func getAtomicTx(
        id: TransactionID,
        encoding: AvalancheEncoding?,
        _ cb: @escaping ApiCallback<(tx: SignedAvalancheTransaction, blockHeight: UInt64)>
    ) {
        let params = GetAtomicTxParams(
            txID: id.cb58(),
            encoding: encoding
        )
        service.call(
            method: "avax.getAtomicTx",
            params: params,
            GetAtomicTxResponse.self,
            SerializableValue.self
        ) { res in
            switch res {
            case .success(let response):
                let transactionData: Data?
                switch response.encoding {
                case .cb58: transactionData = Algos.Base58.from(cb58: response.tx)
                case .hex: transactionData = Data(hex: response.tx)
                }
                guard let transactionData = transactionData else {
                    self.handleError(.custom(description: "Cannot decode transaction", cause: nil), cb)
                    return
                }
                let decoder = self.encoderDecoderProvider.decoder(
                    context: self.context,
                    data: transactionData
                )
                let transaction: SignedAvalancheTransaction
                do {
                    transaction = try decoder.decode()
                } catch {
                    self.handleError(.custom(description: "Cannot decode transaction", cause: error), cb)
                    return
                }
                cb(.success((
                    tx: transaction,
                    blockHeight: UInt64(response.blockHeight)!
                )))
            case .failure(let error):
                self.handleError(.init(request: error), cb)
            }
        }
    }
    
    public func getTransaction(id: TransactionID,
                               result: @escaping ApiCallback<SignedAvalancheTransaction>) {
        getAtomicTx(id: id, encoding: .cb58) { res in
            result(res.map { $0.tx })
        }
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
        let params = GetUTXOsParams(
            addresses: addresses.map { $0.bech },
            limit: limit,
            startIndex: startIndex,
            sourceChain: sourceChain?.cb58(),
            encoding: encoding
        )
        service.call(
            method: "avax.getUTXOs",
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
                }
            )
        }
    }
    
    public func getTransactionCount(
        for address: EthereumAddress,
        _ cb: @escaping ApiCallback<UInt64>
    ) {
        getEth { res in
            switch res {
            case .success(let eth):
                eth.getTransactionCountPromise(address: address).asCallback {
                    cb($0.map(UInt64.init))
                }
            case .failure(let error):
                self.handleError(error, cb)
            }
        }
    }
    
    public struct ExportParams: Encodable {
        public let to: String
        public let amount: UInt64
        public let assetID: String
        public let baseFee: UInt64?
        public let username: String
        public let password: String
    }
    
    public struct ExportResponse: Decodable {
        public let txID: String
    }
    
    public func export(
        to: Address,
        amount: UInt64,
        assetID: AssetID,
        baseFee: UInt64? = nil,
        credentials: CChainApiCredentials,
        _ cb: @escaping ApiCallback<TransactionID>
    ) {
        switch credentials {
        case .password(let username, let password):
            let params = ExportParams(
                to: to.bech,
                amount: amount,
                assetID: assetID.cb58(),
                baseFee: baseFee,
                username: username,
                password: password
            )
            service.call(
                method: "avax.export",
                params: params,
                ExportResponse.self,
                SerializableValue.self
            ) { res in
                cb(res
                    .mapError(AvalancheApiError.init)
                    .map { TransactionID(cb58: $0.txID)! })
            }
        case .account(let account):
            txExport(
                to: to,
                amount: amount,
                assetID: assetID,
                baseFee: baseFee,
                account: account,
                cb
            )
        }
    }
    
    public struct ImportParams: Encodable {
        public let to: String
        public let sourceChain: String
        public let baseFee: UInt64?
        public let username: String
        public let password: String
    }
    
    public struct ImportResponse: Decodable {
        public let txID: String
    }
    
    public func `import`<A: AvalancheTransactionApi>(
        to: EthereumAddress,
        source api: A,
        baseFee: UInt64? = nil,
        credentials: CChainApiCredentials,
        _ cb: @escaping ApiCallback<TransactionID>
    ) {
        switch credentials {
        case .password(let username, let password):
            let params = ImportParams(
                to: to.address,
                sourceChain: api.chainID.value,
                baseFee: baseFee,
                username: username,
                password: password
            )
            service.call(
                method: "avax.import",
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
                baseFee: baseFee,
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
            method: "avax.issueTx",
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
    public var cChain: AvalancheCChainApi {
        return try! self.getAPI(chainID: .alias("C"))
    }
    
    public func cChain(chainID: ChainID) -> AvalancheCChainApi {
        return try! self.getAPI(chainID: chainID)
    }
    
    public func cChain(networkID: NetworkID, chainID: ChainID, vm: String) -> AvalancheCChainApi {
        return AvalancheCChainApi(avalanche: self,
                                  networkID: networkID,
                                  chainID: chainID,
                                  vm: vm)
    }
}
