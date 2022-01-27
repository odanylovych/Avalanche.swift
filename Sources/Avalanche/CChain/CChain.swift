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
    case account(Account, EthAccount? = nil)
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

public class AvalancheCChainApi: AvalancheVMApi {
    public typealias Info = AvalancheCChainApiInfo
    public typealias Keychain = AvalancheCChainApiUTXOAddressManager
    
    public let networkID: NetworkID
    public let hrp: String
    public let info: Info
    
    private let queue: DispatchQueue
    public let xchain: AvalancheXChainApi
    private let addressManager: AvalancheAddressManager?
    private let signer: AvalancheSignatureProvider?
    private let encoderDecoderProvider: AvalancheEncoderDecoderProvider
    private let utxoProvider: AvalancheUtxoProvider
    private let chainIDApiInfos: (String) -> AvalancheVMApiInfo
    private let service: Client
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
            web3Provider = Web3SubscriptionNetworkProvider(network: network, url: url, service: subscribable)
        } else {
            web3Provider = Web3NetworkProvider(network: network,
                                               url: url,
                                               service: connectionProvider.rpc(api: info.vmConnectionType))
        }
        var web3Signer: SignatureProvider? = nil
        if let signer = signer, let manager = addressManager {
            web3Signer = Web3SignatureProvider(chainID: info.chainId, signer: signer, manager: manager)
        }
        web3 = web3swift.web3(provider: web3Provider, signer: web3Signer)
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
    
    private func signAndSend(_ transaction: UnsignedAvalancheTransaction,
                             with addresses: [Address],
                             using utxos: [UTXO],
                             _ cb: @escaping ApiCallback<TransactionID>) {
        guard let keychain = keychain else {
            handleError(.nilAddressManager, cb)
            return
        }
        guard let signer = signer else {
            handleError(.nilSignatureProvider, cb)
            return
        }
        let pathes: [Address: Bip32Path]
        do {
            let extended = try keychain.extended(for: addresses)
            pathes = Dictionary(uniqueKeysWithValues: extended.map { ($0.address, $0.path) })
        } catch {
            handleError(error, cb)
            return
        }
        let extendedTransaction: ExtendedAvalancheTransaction
        do {
            extendedTransaction = try ExtendedAvalancheTransaction(
                transaction: transaction,
                utxos: utxos,
                pathes: pathes
            )
        } catch {
            handleError(error, cb)
            return
        }
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
                    self.queue.async {
                        cb(res)
                    }
                }
            case .failure(let error):
                self.handleError(error, cb)
            }
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
        public let numFetched: UInt32
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
                        fetched: $0.numFetched,
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
            guard let ethAccount = ethAccount else {
                handleError(.custom(description: "EthAccount is not provided", cause: nil), cb)
                return
            }
            guard let keychain = keychain else {
                handleError(.nilAddressManager, cb)
                return
            }
            let fromAddresses: [Address]
            do {
                fromAddresses = try keychain.get(cached: account)
            } catch {
                handleError(error, cb)
                return
            }
            let iterator = utxoProvider.utxos(api: self, addresses: fromAddresses)
            UTXOHelper.getAll(iterator: iterator) { res in
                switch res {
                case .success(let utxos):
                    self.xchain.getAvaxAssetID { res in
                        switch res {
                        case .success(let avaxAssetID):
                            let destinationChain = self.chainIDApiInfos(to.chainId).blockchainID
                            let fee = baseFee ?? UInt64(self.info.txFee)
                            let address = ethAccount.address
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
                                    let transaction: UnsignedAvalancheTransaction
                                    do {
                                        let encoder = self.encoderDecoderProvider.encoder()
                                        transaction = CChainExportTransaction(
                                            networkID: self.networkID,
                                            blockchainID: self.info.blockchainID,
                                            destinationChain: destinationChain,
                                            inputs: inputs,
                                            exportedOutputs: try exportedOutputs.sorted {
                                                try encoder.encode($0).output < encoder.encode($1).output
                                            }
                                        )
                                    } catch {
                                        self.handleError(error, cb)
                                        return
                                    }
                                    self.signAndSend(transaction, with: fromAddresses, using: utxos, cb)
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
        credentials: CChainCredentials,
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
        case .account(let account, _):
            guard let keychain = keychain else {
                handleError(.nilAddressManager, cb)
                return
            }
            let fromAddresses: [Address]
            do {
                fromAddresses = try keychain.get(cached: account)
            } catch {
                handleError(error, cb)
                return
            }
            let iterator = utxoProvider.utxos(api: self, addresses: fromAddresses)
            UTXOHelper.getAll(iterator: iterator, sourceChain: sourceChain) { res in
                switch res {
                case .success(let utxos):
                    self.xchain.getAvaxAssetID { res in
                        switch res {
                        case .success(let avaxAssetID):
                            let feeAssetID = avaxAssetID
                            let fee = baseFee ?? UInt64(self.info.txFee)
                            var feePaid: UInt64 = 0
                            var importInputs = [TransferableInput]()
                            var assetIDAmount = [AssetID: UInt64]()
                            for utxo in utxos.filter({ type(of: $0.output) == SECP256K1TransferOutput.self }) {
                                let output = utxo.output as! SECP256K1TransferOutput
                                var inFeeAmount = output.amount
                                if fee > 0 && feePaid < fee && utxo.assetID == feeAssetID {
                                    feePaid += inFeeAmount
                                    if feePaid > fee {
                                        inFeeAmount = feePaid - fee
                                        feePaid = fee
                                    } else {
                                        inFeeAmount = 0
                                    }
                                }
                                let input: TransferableInput
                                do {
                                    input = TransferableInput(
                                        transactionID: utxo.transactionID,
                                        utxoIndex: utxo.utxoIndex,
                                        assetID: utxo.assetID,
                                        input: try SECP256K1TransferInput(
                                            amount: output.amount,
                                            addressIndices: output.getAddressIndices(for: output.addresses)
                                        )
                                    )
                                } catch {
                                    self.handleError(error, cb)
                                    return
                                }
                                importInputs.append(input)
                                if let amount = assetIDAmount[utxo.assetID] {
                                    inFeeAmount += amount
                                }
                                assetIDAmount[utxo.assetID] = inFeeAmount
                            }
                            var outputs = [EVMOutput]()
                            for (assetID, amount) in assetIDAmount {
                                outputs.append(EVMOutput(
                                    address: to,
                                    amount: amount,
                                    assetID: assetID
                                ))
                            }
                            let transaction: UnsignedAvalancheTransaction
                            do {
                                let encoder = self.encoderDecoderProvider.encoder()
                                transaction = CChainImportTransaction(
                                    networkID: self.networkID,
                                    blockchainID: self.info.blockchainID,
                                    sourceChain: sourceChain,
                                    importedInputs: try importInputs.sorted {
                                        try encoder.encode($0).output < encoder.encode($1).output
                                    },
                                    outputs: outputs
                                )
                            } catch {
                                self.handleError(error, cb)
                                return
                            }
                            self.signAndSend(transaction, with: fromAddresses, using: utxos, cb)
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
