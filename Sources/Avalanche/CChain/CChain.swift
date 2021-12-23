//
//  CChain.swift
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

public enum CChainCredentials {
    case password(username: String, password: String)
    case account(EthAccount)
}

public class AvalancheCChainApiInfo: AvalancheBaseVMApiInfo {
    public let txFee: BigUInt
    public let gasPrice: BigUInt
    public let chainId: UInt32
    
    public init(
        txFee: BigUInt, gasPrice: BigUInt, chainId: UInt32, blockchainID: BlockchainID,
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

public class AvalancheCChainApi: AvalancheApi {
    public typealias Info = AvalancheCChainApiInfo
    
    private struct SubscriptionId: Decodable {
        let subscription: String
    }
    
    public let networkID: NetworkID
    public let hrp: String
    public let info: Info
    
    private let queue: DispatchQueue
    private var subscriptions: Dictionary<String, (Data) -> Void>
    private var subscriptionId: UInt?
    //FIX: public let network: AvalancheSubscribableRpcConnection
    public let xchain: AvalancheXChainApi
    public let keychain: AvalancheAddressManager?
    private let signer: AvalancheSignatureProvider?
    private let encoderDecoderProvider: AvalancheEncoderDecoderProvider
    private let chainIDApiInfos: (String) -> AvalancheVMApiInfo
    private let service: Client
    
    public required init(avalanche: AvalancheCore, networkID: NetworkID, hrp: String, info: Info) {
        //FIX: self.network = avalanche.connections.wsRpcConnection(for: info.wsApiPath)
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
        keychain = avalanche.addressManager
        signer = avalanche.signatureProvider
        encoderDecoderProvider = avalanche.encoderDecoderProvider
        service = avalanche.connectionProvider.rpc(api: info.connectionType)
        self.subscriptions = [:]
        self.subscriptionId = nil
    }
    
    private func handleError<R: Any>(_ error: AvalancheApiError, _ cb: @escaping ApiCallback<R>) {
        self.queue.async {
            cb(.failure(error))
        }
    }
    
    private func handleError<R: Any>(_ error: Error, _ cb: @escaping ApiCallback<R>) {
        self.queue.async {
            cb(.failure(.custom(cause: error)))
        }
    }
    
    private func signAndSend(_ transaction: UnsignedEthereumTransaction,
                             with addresses: [EthAddress],
                             chainId: UInt64,
                             _ cb: @escaping ApiCallback<TransactionID>) {
        guard let keychain = keychain else {
            handleError(.nilAddressManager, cb)
            return
        }
        guard let signer = signer else {
            handleError(.nilSignatureProvider, cb)
            return
        }
        let pathes: [EthAddress: Bip32Path]
        do {
            let extended = try keychain.extended(eth: addresses)
            pathes = Dictionary(uniqueKeysWithValues: extended.map { ($0.address, $0.path) })
        } catch {
            handleError(error, cb)
            return
        }
        let extendedTransaction = EthereumTransactionExt(
            tx: transaction,
            chainId: chainId,
            pathes: pathes
        )
        signer.sign(transaction: extendedTransaction) { res in
            switch res {
            case .success(let signed):
                let tx: String
                do {
                    tx = try self.encoderDecoderProvider.encoder().encode(signed).output.cb58()
                } catch {
                    self.handleError(error, cb)
                    return
                }
                self.issueTx(tx: tx, encoding: AvalancheEncoding.cb58) { res in
                    cb(res)
                }
            case .failure(let error):
                self.handleError(error, cb)
            }
        }
    }
    
    private func processMessage(data: Data) {
        do {
            /*//FIX: let (_, id) = try network.parseInfo(from: data, SubscriptionId.self)
            guard let handler = subscriptions[id.subscription] else {
                return
            }
            handler(data)*/
        } catch {}
    }
    
    private func subscribeIfNeeded() {
        guard subscriptionId == nil else { return }
        /*//FIX: self.subscriptionId = network.subscribe { [weak self] data, _ in
            self?.processMessage(data: data)
        }*/
    }
    
    private func unsubscribeIfNeeded() {
        guard let subId = subscriptionId, subscriptions.count == 0 else { return }
        subscriptionId = nil
        //FIX: network.unsubscribe(id: subId)
    }
    
    // Subscription Example. Should be updated to proper types
    /*//FIX: public func eth_subscribe<T: CChainSubscriptionType>(
        _ params: T,
        result: @escaping AvalancheRpcConnectionCallback<T, CChainSubscription<T.Event>, CChainError>
    ) {
        self.subscribeIfNeeded()
        /*//FIX: network.call(method: "eth_subscribe", params: params, String.self) { res in
            result(res.map {
                let sub = CChainSubscription<T.Event>(id: $0, api: self)
                self.subscriptions[$0] = sub.handler
                return sub
            })
        }*/
    }*/

    /*//FIX: public func eth_unsubscribe<S: CChainSubscription<M>, M: Decodable>(
        _ subcription: S, result: @escaping AvalancheRpcConnectionCallback<String, Bool, CChainError>
    ) {
        // TODO: fix multithreading
        self.subscriptions.removeValue(forKey: subcription.id)
        self.unsubscribeIfNeeded()
        //FIX: network.call(method: "eth_unsubscribe", params: subcription.id, Bool.self, response: result)
    }*/
    
    public func getChainID(_ cb: @escaping ApiCallback<UInt64>) {
        fatalError("Not implemented")
    }
    
    public func getTransactionCount(
        for address: EthAddress,
        _ cb: @escaping ApiCallback<UInt64>
    ) {
        fatalError("Not implemented")
    }
    
    public struct ExportParams: Encodable {
        public let to: String
        public let amount: UInt64
        public let assetID: String
        public let baseFee: UInt64
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
        baseFee: UInt64,
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
        case .account(let account):
            xchain.getAvaxAssetID { res in
                switch res {
                case .success(let avaxAssetID):
                    let destinationChain = self.chainIDApiInfos(to.chainId).blockchainID
                    let fee = UInt64(self.info.txFee)
                    let address = account.address
                    self.getTransactionCount(for: address) { res in
                        switch res {
                        case .success(let nonce):
                            var inputs = [EVMInput]()
                            if assetID == avaxAssetID {
                                inputs.append(EVMInput(
                                    address: address,
                                    amount: amount + fee,
                                    assetID: assetID,
                                    nonce: nonce
                                ))
                            } else {
                                inputs.append(contentsOf: [
                                    EVMInput(
                                        address: address,
                                        amount: fee,
                                        assetID: avaxAssetID,
                                        nonce: nonce
                                    ),
                                    EVMInput(
                                        address: address,
                                        amount: amount,
                                        assetID: assetID,
                                        nonce: nonce
                                    )
                                ])
                            }
                            let exportedOutputs: [TransferableOutput]
                            do {
                                exportedOutputs = [
                                    TransferableOutput(
                                        assetID: assetID,
                                        output: try SECP256K1TransferOutput(
                                            amount: amount,
                                            locktime: Date(timeIntervalSince1970: 0),
                                            threshold: 1,
                                            addresses: [to]
                                        )
                                    )
                                ]
                            } catch {
                                self.handleError(error, cb)
                                return
                            }
                            // TODO: sort exportedOutputs
                            let transaction: UnsignedEthereumTransaction
                            do {
                                transaction = UnsignedEthereumTransaction()
                                // TODO: CChainExportTransaction
        //                        transaction = try CChainExportTransaction(
        //                            networkID: self.networkID,
        //                            blockchainID: self.info.blockchainID,
        //                            destinationChain: destinationChain,
        //                            inputs: inputs,
        //                            exportedOutputs: exportedOutputs
        //                        )
                            } catch {
                                self.handleError(error, cb)
                                return
                            }
                            self.getChainID { res in
                                switch res {
                                case .success(let chainId):
                                    self.signAndSend(transaction, with: [address], chainId: chainId) { res in
                                        cb(res)
                                    }
                                case .failure(let error):
                                    self.handleError(error, cb)
                                }
                            }
                        case .failure(let error):
                            self.handleError(error, cb)
                        }
                    }
                case .failure(let error):
                    self.handleError(error, cb)
                }
            }
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
