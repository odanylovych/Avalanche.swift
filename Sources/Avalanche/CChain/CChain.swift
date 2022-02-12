//
//  CChain.swift
//  
//
//  Created by Yehor Popovych on 10/14/20.
//

import Foundation
#if !COCOAPODS
import BigInt
import web3swift
import RPC
import Serializable
#endif

public enum CChainCredentials {
    case password(username: String, password: String)
    case account(Account, EthAccount)
}

public class AvalancheCChainApiInfo: AvalancheBaseVMApiInfo {
    public let txFee: BigUInt
    public let gasPrice: BigUInt
    public let chainId: BigUInt
    
    public init(
        txFee: BigUInt, gasPrice: BigUInt, chainId: BigUInt, blockchainID: BlockchainID,
        alias: String? = nil, vm: String = "evm"
    ) {
        self.txFee = txFee
        self.gasPrice = gasPrice
        self.chainId = chainId
        super.init(blockchainID: blockchainID, alias: alias, vm: vm)
    }
    
    override public var connectionType: ApiConnectionType {
        .cChain(alias: alias, blockchainID: blockchainID)
    }
    
    public var vmConnectionType: ApiConnectionType {
        .cChainVM(alias: alias, blockchainID: blockchainID)
    }
}

public class AvalancheCChainApi: AvalancheTransactionApi {
    public typealias Info = AvalancheCChainApiInfo
    public typealias Keychain = AvalancheCChainApiUTXOAddressManager
    
    public let networkID: NetworkID
    public let hrp: String
    public let info: Info
    
    public let queue: DispatchQueue
    let xchain: AvalancheXChainApi
    private let addressManager: AvalancheAddressManager?
    public let signer: AvalancheSignatureProvider?
    public let encoderDecoderProvider: AvalancheEncoderDecoderProvider
    public let utxoProvider: AvalancheUtxoProvider
    let chainIDApiInfos: (String) -> AvalancheVMApiInfo
    private let service: Client
    private let vmService: Client
    private let web3: web3
    
    public var keychain: AvalancheCChainApiUTXOAddressManager? {
        addressManager.map {
            AvalancheCChainApiUTXOAddressManager(manager: $0, api: self)
        }
    }
    
    private var context: AvalancheDecoderContext {
        DefaultAvalancheDecoderContext(
            hrp: hrp,
            chainId: info.chainId,
            dynamicParser: CChainDynamicTypeRegistry.instance
        )
    }
    
    public var eth: web3.Eth { web3.eth }
    public var personal: web3.Personal { web3.personal }
    public var txPool: web3.TxPool { web3.txPool }
    
    public required init(avalanche: AvalancheCore, networkID: NetworkID, hrp: String, info: Info) {
        self.hrp = hrp
        self.networkID = networkID
        self.info = info
        
        queue = avalanche.settings.queue
        xchain = avalanche.xChain
        chainIDApiInfos = {
            [
                avalanche.xChain.info.alias!: avalanche.xChain.info,
                avalanche.pChain.info.alias!: avalanche.pChain.info
            ][$0]!
        }
        let addressManagerProvider = avalanche.settings.addressManagerProvider
        addressManager = addressManagerProvider.manager(ava: avalanche)
        signer = avalanche.signatureProvider
        encoderDecoderProvider = avalanche.settings.encoderDecoderProvider
        utxoProvider = avalanche.settings.utxoProvider
        let connectionProvider = avalanche.connectionProvider
        service = connectionProvider.rpc(api: info.connectionType)
        let url = URL(string: "http://notused")!
        let network: Networks = .Custom(networkID: info.chainId)
        let web3Provider: Web3Provider
        if let subscribable = connectionProvider.subscribableRPC(api: info.vmConnectionType) {
            vmService = subscribable
            web3Provider = Web3SubscriptionNetworkProvider(network: network, url: url, service: subscribable)
        } else {
            vmService = connectionProvider.rpc(api: info.vmConnectionType)
            web3Provider = Web3NetworkProvider(network: network, url: url, service: vmService)
        }
        var web3Signer: SignatureProvider? = nil
        if let signer = signer, let manager = addressManager {
            web3Signer = Web3SignatureProvider(chainID: info.chainId, signer: signer, manager: manager)
        }
        web3 = web3swift.web3(provider: web3Provider, signer: web3Signer)
    }
    
    deinit {
        if let vmService = vmService as? Connectable {
            vmService.disconnect()
        }
    }
    
    public func getAvaxAssetID(_ cb: @escaping ApiCallback<AssetID>) {
        xchain.getAvaxAssetID(cb)
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
        eth.getTransactionCountPromise(address: address).asCallback {
            cb($0.map(UInt64.init))
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
        credentials: CChainCredentials,
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
        case .account(let account, let ethAccount):
            txExport(
                to: to,
                amount: amount,
                assetID: assetID,
                baseFee: baseFee,
                account: account,
                ethAccount: ethAccount,
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
    
    public func `import`(
        to: EthereumAddress,
        sourceChain: BlockchainID,
        baseFee: UInt64? = nil,
        credentials: AvalancheVmApiCredentials,
        _ cb: @escaping ApiCallback<TransactionID>
    ) {
        switch credentials {
        case .password(let username, let password):
            let params = ImportParams(
                to: to.address,
                sourceChain: sourceChain.cb58(),
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
                sourceChain: sourceChain,
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
        return try! self.getAPI()
    }
    
    public func cChain(networkID: NetworkID, hrp: String, info: AvalancheCChainApi.Info) -> AvalancheCChainApi {
        return self.createAPI(networkID: networkID, hrp: hrp, info: info)
    }
}
