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

public class AvalancheXChainApi: AvalancheVMApi {
    public typealias Info = AvalancheXChainApiInfo
    public typealias Keychain = AvalancheXChainApiAddressManager
    
    private let queue: DispatchQueue
    private let addressManager: AvalancheAddressManager?
    private let utxoProvider: AvalancheUtxoProvider
    private let signer: AvalancheSignatureProvider?
    private let chainIDApiInfos: (String) -> AvalancheVMApiInfo
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
        signer = avalanche.signatureProvider
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
    
    private func getAvaxAssetID(_ cb: @escaping ApiCallback<AssetID>) {
        getAssetDescription(assetID: AvalancheConstants.avaxAssetAlias) { res in
            cb(res.map { avaxAssetID, _, _, _ in
                avaxAssetID
            })
        }
    }
    
    private func getInputsOutputs(
        assetID: AssetID,
        from: [Address],
        to: [Address],
        change: [Address],
        utxos: [UTXO],
        fee: UInt64
    ) throws -> ([TransferableInput], [TransferableOutput]) {
        var aad = AssetAmountDestination(
            senders: from,
            destinations: to,
            changeAddresses: change
        )
        aad.assetAmounts[assetID] = AssetAmount(assetID: assetID, amount: 0, burn: fee)
        let spendable = try UTXOHelper.getMinimumSpendable(aad: aad, utxos: utxos)
        let inputs = spendable.inputs
        let outputs = spendable.outputs + spendable.change
        return (inputs, outputs)
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
                    tx = try AEncoder().encode(signed).output.cb58()
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
            guard let keychain = keychain else {
                handleError(.nilAddressManager, cb)
                return
            }
            let fromAddresses: [Address]
            do {
                fromAddresses = try from ?? keychain.get(cached: account)
            } catch {
                handleError(error, cb)
                return
            }
            let utxoIterator = utxoProvider.utxos(api: self, addresses: fromAddresses)
            UTXOHelper.getAll(iterator: utxoIterator) { res in
                switch res {
                case .success(let utxos):
                    self.getAvaxAssetID { res in
                        switch res {
                        case .success(let avaxAssetID):
                            let changeAddress: Address
                            do {
                                changeAddress = try change ?? keychain.newChange(for: account)
                            } catch {
                                self.handleError(error, cb)
                                return
                            }
                            let fee = UInt64(self.info.creationTxFee)
                            let (inputs, outputs): ([TransferableInput], [TransferableOutput])
                            do {
                                (inputs, outputs) = try self.getInputsOutputs(
                                    assetID: avaxAssetID,
                                    from: fromAddresses,
                                    to: fromAddresses,
                                    change: [changeAddress],
                                    utxos: utxos,
                                    fee: fee
                                )
                            } catch {
                                self.handleError(error, cb)
                                return
                            }
                            let initialStates: [InitialState]
                            do {
                                initialStates = [InitialState(
                                    featureExtensionID: .secp256K1,
                                    outputs: try initialHolders.map { address, amount in
                                        try SECP256K1TransferOutput(
                                            amount: amount,
                                            locktime: Date(timeIntervalSince1970: 0),
                                            threshold: 1,
                                            addresses: [address]
                                        )
                                    } + [
                                        try SECP256K1MintOutput(
                                            locktime: Date(timeIntervalSince1970: 0),
                                            threshold: 1,
                                            addresses: fromAddresses
                                        )
                                    ]
                                )]
                            } catch {
                                self.handleError(error, cb)
                                return
                            }
                            let transaction: CreateAssetTransaction
                            do {
                                transaction = try CreateAssetTransaction(
                                    networkID: self.networkID,
                                    blockchainID: self.info.blockchainID,
                                    outputs: outputs,
                                    inputs: inputs,
                                    memo: memo,
                                    name: name,
                                    symbol: symbol,
                                    denomination: denomination ?? 0,
                                    initialStates: initialStates
                                )
                            }
                            catch {
                                self.handleError(error, cb)
                                return
                            }
                            guard TransactionHelper.checkGooseEgg(
                                avax: avaxAssetID,
                                transaction: transaction,
                                outputTotal: fee
                            ) else {
                                self.handleError(TransactionBuilderError.gooseEggCheckError, cb)
                                return
                            }
                            self.signAndSend(transaction, with: fromAddresses, using: utxos) { res in
                                cb(res.map { transactionID in
                                    (assetID: AssetID(data: transactionID.raw)!, change: changeAddress)
                                })
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
            guard let keychain = keychain else {
                handleError(.nilAddressManager, cb)
                return
            }
            let fromAddresses: [Address]
            do {
                fromAddresses = try from ?? keychain.get(cached: account)
            } catch {
                handleError(error, cb)
                return
            }
            let iterator = utxoProvider.utxos(api: self, addresses: fromAddresses)
            UTXOHelper.getAll(iterator: iterator) { res in
                switch res {
                case .success(let utxos):
                    self.getAvaxAssetID { res in
                        switch res {
                        case .success(let avaxAssetID):
                            let utxo = utxos.first { type(of: $0.output) == SECP256K1MintOutput.self }!
                            let transferOutput: SECP256K1TransferOutput
                            do {
                                transferOutput = try SECP256K1TransferOutput(
                                    amount: amount,
                                    locktime: Date(timeIntervalSince1970: 0),
                                    threshold: 1,
                                    addresses: fromAddresses
                                )
                            } catch {
                                self.handleError(error, cb)
                                return
                            }
                            let changeAddress: Address
                            do {
                                changeAddress = try change ?? keychain.newChange(for: account)
                            } catch {
                                self.handleError(error, cb)
                                return
                            }
                            let fee = UInt64(self.info.txFee)
                            let (inputs, outputs): ([TransferableInput], [TransferableOutput])
                            do {
                                (inputs, outputs) = try self.getInputsOutputs(
                                    assetID: avaxAssetID,
                                    from: fromAddresses,
                                    to: fromAddresses,
                                    change: [changeAddress],
                                    utxos: utxos,
                                    fee: fee
                                )
                            } catch {
                                self.handleError(error, cb)
                                return
                            }
                            let mintOutput = utxo.output as! SECP256K1MintOutput
                            let addressIndices = mintOutput.getAddressIndices(for: fromAddresses)
                            let mintOperation = SECP256K1MintOperation(
                                addressIndices: addressIndices,
                                mintOutput: mintOutput,
                                transferOutput: transferOutput
                            )
                            let transferableOperation = TransferableOperation(
                                assetID: utxo.assetID,
                                utxoIDs: [
                                    UTXOID(
                                        transactionID: utxo.transactionID,
                                        utxoIndex: utxo.utxoIndex
                                    )
                                ],
                                transferOperation: mintOperation
                            )
                            let transaction: UnsignedAvalancheTransaction
                            do {
                                transaction = try OperationTransaction(
                                    networkID: self.networkID,
                                    blockchainID: self.info.blockchainID,
                                    outputs: outputs,
                                    inputs: inputs,
                                    memo: memo,
                                    operations: [transferableOperation]
                                )
                            } catch {
                                self.handleError(error, cb)
                                return
                            }
                            guard TransactionHelper.checkGooseEgg(
                                avax: avaxAssetID,
                                transaction: transaction
                            ) else {
                                self.handleError(TransactionBuilderError.gooseEggCheckError, cb)
                                return
                            }
                            self.signAndSend(transaction, with: fromAddresses, using: utxos) { res in
                                cb(res.map { transactionID in
                                    (txID: transactionID, change: changeAddress)
                                })
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
            guard let keychain = keychain else {
                handleError(.nilAddressManager, cb)
                return
            }
            let fromAddresses: [Address]
            do {
                fromAddresses = try from ?? keychain.get(cached: account)
            } catch {
                handleError(error, cb)
                return
            }
            let utxoIterator = utxoProvider.utxos(api: self, addresses: fromAddresses)
            UTXOHelper.getAll(iterator: utxoIterator) { res in
                switch res {
                case .success(let utxos):
                    self.getAvaxAssetID { res in
                        switch res {
                        case .success(let avaxAssetID):
                            let changeAddress: Address
                            do {
                                changeAddress = try change ?? keychain.newChange(for: account)
                            } catch {
                                self.handleError(error, cb)
                                return
                            }
                            let fee = UInt64(self.info.creationTxFee)
                            let (inputs, outputs): ([TransferableInput], [TransferableOutput])
                            do {
                                (inputs, outputs) = try self.getInputsOutputs(
                                    assetID: avaxAssetID,
                                    from: fromAddresses,
                                    to: fromAddresses,
                                    change: [changeAddress],
                                    utxos: utxos,
                                    fee: fee
                                )
                            } catch {
                                self.handleError(error, cb)
                                return
                            }
                            let initialStates: [InitialState]
                            do {
                                initialStates = [InitialState(
                                    featureExtensionID: .secp256K1,
                                    outputs: try minterSets.map { addresses, threshold in
                                        try SECP256K1MintOutput(
                                            locktime: Date(timeIntervalSince1970: 0),
                                            threshold: threshold,
                                            addresses: addresses
                                        )
                                    }
                                )]
                            } catch {
                                self.handleError(error, cb)
                                return
                            }
                            let transaction: CreateAssetTransaction
                            do {
                                transaction = try CreateAssetTransaction(
                                    networkID: self.networkID,
                                    blockchainID: self.info.blockchainID,
                                    outputs: outputs,
                                    inputs: inputs,
                                    memo: memo,
                                    name: name,
                                    symbol: symbol,
                                    denomination: denomination ?? 0,
                                    initialStates: initialStates
                                )
                            }
                            catch {
                                self.handleError(error, cb)
                                return
                            }
                            guard TransactionHelper.checkGooseEgg(
                                avax: avaxAssetID,
                                transaction: transaction,
                                outputTotal: fee
                            ) else {
                                self.handleError(TransactionBuilderError.gooseEggCheckError, cb)
                                return
                            }
                            self.signAndSend(transaction, with: fromAddresses, using: utxos) { res in
                                cb(res.map { transactionID in
                                    (assetID: AssetID(data: transactionID.raw)!, change: changeAddress)
                                })
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
            guard let keychain = keychain else {
                handleError(.nilAddressManager, cb)
                return
            }
            let fromAddresses: [Address]
            do {
                fromAddresses = try from ?? keychain.get(cached: account)
            } catch {
                handleError(error, cb)
                return
            }
            let iterator = utxoProvider.utxos(api: self, addresses: fromAddresses)
            UTXOHelper.getAll(iterator: iterator) { res in
                switch res {
                case .success(let utxos):
                    self.getAvaxAssetID { res in
                        switch res {
                        case .success(let avaxAssetID):
                            let changeAddress: Address
                            do {
                                changeAddress = try change ?? keychain.newChange(for: account)
                            } catch {
                                self.handleError(error, cb)
                                return
                            }
                            let fee = UInt64(self.info.creationTxFee)
                            let (inputs, outputs): ([TransferableInput], [TransferableOutput])
                            do {
                                (inputs, outputs) = try self.getInputsOutputs(
                                    assetID: avaxAssetID,
                                    from: fromAddresses,
                                    to: fromAddresses,
                                    change: [changeAddress],
                                    utxos: utxos,
                                    fee: fee
                                )
                            } catch {
                                self.handleError(error, cb)
                                return
                            }
                            let initialStates: [InitialState]
                            do {
                                initialStates = [InitialState(
                                    featureExtensionID: .nft,
                                    outputs: try minterSets.enumerated().map { index, minterSet in
                                        try NFTMintOutput(
                                            groupID: UInt32(index),
                                            locktime: Date(timeIntervalSince1970: 0),
                                            threshold: minterSet.threshold,
                                            addresses: minterSet.minters
                                        )
                                    }
                                )]
                            } catch {
                                self.handleError(error, cb)
                                return
                            }
                            let transaction: UnsignedAvalancheTransaction
                            do {
                                transaction = try CreateAssetTransaction(
                                    networkID: self.networkID,
                                    blockchainID: self.info.blockchainID,
                                    outputs: outputs,
                                    inputs: inputs,
                                    memo: memo,
                                    name: name,
                                    symbol: symbol,
                                    denomination: 0,
                                    initialStates: initialStates
                                )
                            } catch {
                                self.handleError(error, cb)
                                return
                            }
                            guard TransactionHelper.checkGooseEgg(
                                avax: avaxAssetID,
                                transaction: transaction,
                                outputTotal: fee
                            ) else {
                                self.handleError(TransactionBuilderError.gooseEggCheckError, cb)
                                return
                            }
                            self.signAndSend(transaction, with: fromAddresses, using: utxos) { res in
                                cb(res.map { transactionID in
                                    (assetID: AssetID(data: transactionID.raw)!, change: changeAddress)
                                })
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
            guard let keychain = keychain else {
                handleError(.nilAddressManager, cb)
                return
            }
            let fromAddresses: [Address]
            do {
                fromAddresses = try from ?? keychain.get(cached: account)
            } catch {
                handleError(error, cb)
                return
            }
            let iterator = utxoProvider.utxos(api: self, addresses: fromAddresses)
            UTXOHelper.getAll(iterator: iterator) { res in
                switch res {
                case .success(let utxos):
                    self.getAvaxAssetID { res in
                        switch res {
                        case .success(let avaxAssetID):
                            let utxo = utxos.first { type(of: $0.output) == NFTMintOutput.self }!
                            let outputOwners: NFTMintOperationOutput
                            do {
                                outputOwners = try NFTMintOperationOutput(
                                    locktime: Date(timeIntervalSince1970: 0),
                                    threshold: 1,
                                    addresses: fromAddresses
                                )
                            } catch {
                                self.handleError(error, cb)
                                return
                            }
                            let changeAddress: Address
                            do {
                                changeAddress = try change ?? keychain.newChange(for: account)
                            } catch {
                                self.handleError(error, cb)
                                return
                            }
                            let fee = UInt64(self.info.txFee)
                            let (inputs, outputs): ([TransferableInput], [TransferableOutput])
                            do {
                                (inputs, outputs) = try self.getInputsOutputs(
                                    assetID: avaxAssetID,
                                    from: fromAddresses,
                                    to: fromAddresses,
                                    change: [changeAddress],
                                    utxos: utxos,
                                    fee: fee
                                )
                            } catch {
                                self.handleError(error, cb)
                                return
                            }
                            let mintOutput = utxo.output as! NFTMintOutput
                            let addressIndices = mintOutput.getAddressIndices(for: fromAddresses)
                            let nftMintOperation: Operation
                            do {
                                nftMintOperation = try NFTMintOperation(
                                    addressIndices: addressIndices,
                                    groupID: 0,
                                    payload: Data(hex: payload)!,
                                    outputs: [outputOwners]
                                )
                            } catch {
                                self.handleError(error, cb)
                                return
                            }
                            let transferableOperation = TransferableOperation(
                                assetID: utxo.assetID,
                                utxoIDs: [
                                    UTXOID(
                                        transactionID: utxo.transactionID,
                                        utxoIndex: utxo.utxoIndex
                                    )
                                ],
                                transferOperation: nftMintOperation
                            )
                            let transaction: UnsignedAvalancheTransaction
                            do {
                                transaction = try OperationTransaction(
                                    networkID: self.networkID,
                                    blockchainID: self.info.blockchainID,
                                    outputs: outputs,
                                    inputs: inputs,
                                    memo: memo,
                                    operations: [transferableOperation]
                                )
                            } catch {
                                self.handleError(error, cb)
                                return
                            }
                            guard TransactionHelper.checkGooseEgg(
                                avax: avaxAssetID,
                                transaction: transaction
                            ) else {
                                self.handleError(TransactionBuilderError.gooseEggCheckError, cb)
                                return
                            }
                            self.signAndSend(transaction, with: fromAddresses, using: utxos) { res in
                                cb(res.map { transactionID in
                                    (txID: transactionID, change: changeAddress)
                                })
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
            guard let keychain = keychain else {
                handleError(.nilAddressManager, cb)
                return
            }
            let fromAddresses: [Address]
            do {
                fromAddresses = try from ?? keychain.get(cached: account)
            } catch {
                handleError(error, cb)
                return
            }
            let iterator = utxoProvider.utxos(api: self, addresses: fromAddresses)
            UTXOHelper.getAll(iterator: iterator) { res in
                switch res {
                case .success(let utxos):
                    self.getAvaxAssetID { res in
                        switch res {
                        case .success(let avaxAssetID):
                            let changeAddress = change ?? to
                            let fee = UInt64(self.info.txFee)
                            let inputs: [TransferableInput]
                            let outputs: [TransferableOutput]
                            let exportOutputs: [TransferableOutput]
                            do {
                                var aad = AssetAmountDestination(
                                    senders: fromAddresses,
                                    destinations: [to],
                                    changeAddresses: [changeAddress]
                                )
                                let feeAssetID = avaxAssetID
                                if assetID == feeAssetID {
                                    aad.assetAmounts[assetID] = AssetAmount(assetID: assetID, amount: amount, burn: fee)
                                } else {
                                    aad.assetAmounts[assetID] = AssetAmount(assetID: assetID, amount: amount, burn: 0)
                                    aad.assetAmounts[feeAssetID] = AssetAmount(assetID: feeAssetID, amount: 0, burn: fee)
                                }
                                let spendable = try UTXOHelper.getMinimumSpendable(aad: aad, utxos: utxos)
                                inputs = spendable.inputs
                                outputs = spendable.change
                                exportOutputs = spendable.outputs
                            } catch {
                                self.handleError(error, cb)
                                return
                            }
                            let destinationChain = self.chainIDApiInfos(to.chainId).blockchainID
                            let transaction: UnsignedAvalancheTransaction
                            do {
                                transaction = try ExportTransaction(
                                    networkID: self.networkID,
                                    blockchainID: self.info.blockchainID,
                                    outputs: outputs,
                                    inputs: inputs,
                                    memo: memo,
                                    destinationChain: destinationChain,
                                    transferableOutputs: exportOutputs
                                )
                            } catch {
                                self.handleError(error, cb)
                                return
                            }
                            guard TransactionHelper.checkGooseEgg(
                                avax: avaxAssetID,
                                transaction: transaction
                            ) else {
                                self.handleError(TransactionBuilderError.gooseEggCheckError, cb)
                                return
                            }
                            self.signAndSend(transaction, with: fromAddresses, using: utxos) { res in
                                cb(res.map { transactionID in
                                    (txID: transactionID, change: changeAddress)
                                })
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
    
    public struct GetAllBalancesParams: Encodable {
        public let address: String
    }
    
    public struct Balance: Decodable {
        public let asset: String
        public let balance: UInt64
    }
    
    public struct GetAllBalancesResponse: Decodable {
        public let balances: [Balance]
    }
    
    public func getAllBalances(
        address: Address,
        _ cb: @escaping ApiCallback<[(asset: AssetID, balance: UInt64)]>
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
    
    public struct GetAssetDescriptionParams: Encodable {
        public let assetID: String
    }
    
    public struct GetAssetDescriptionResponse: Decodable {
        public let assetID: String
        public let name: String
        public let symbol: String
        public let denomination: UInt32
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
                    denomination: $0.denomination
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
                    self.getAvaxAssetID { res in
                        switch res {
                        case .success(let avaxAssetID):
                            let changeAddress: Address
                            do {
                                changeAddress = try keychain.newChange(for: account)
                            } catch {
                                self.handleError(error, cb)
                                return
                            }
                            let feeAssetID = avaxAssetID
                            var fee = UInt64(self.info.txFee)
                            var feePaid: UInt64 = 0
                            var importInputs = [TransferableInput]()
                            var outputs = [TransferableOutput]()
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
                                if inFeeAmount > 0 {
                                    do {
                                        outputs.append(TransferableOutput(
                                            assetID: utxo.assetID,
                                            output: try type(of: output).init(
                                                amount: inFeeAmount,
                                                locktime: Date(timeIntervalSince1970: 0),
                                                threshold: 1,
                                                addresses: [to]
                                            )
                                        ))
                                    } catch {
                                        self.handleError(error, cb)
                                        return
                                    }
                                }
                            }
                            fee = fee - feePaid
                            var inputs = [TransferableInput]()
                            if fee > 0 {
                                do {
                                    (inputs, outputs) = try self.getInputsOutputs(
                                        assetID: feeAssetID,
                                        from: fromAddresses,
                                        to: [to],
                                        change: [changeAddress],
                                        utxos: utxos,
                                        fee: fee
                                    )
                                } catch {
                                    self.handleError(error, cb)
                                    return
                                }
                            }
                            let transaction: UnsignedAvalancheTransaction
                            do {
                                transaction = try ImportTransaction(
                                    networkID: self.networkID,
                                    blockchainID: self.info.blockchainID,
                                    outputs: outputs,
                                    inputs: inputs,
                                    memo: memo,
                                    sourceChain: sourceChain,
                                    transferableInputs: importInputs
                                )
                            } catch {
                                self.handleError(error, cb)
                                return
                            }
                            guard TransactionHelper.checkGooseEgg(
                                avax: avaxAssetID,
                                transaction: transaction
                            ) else {
                                self.handleError(TransactionBuilderError.gooseEggCheckError, cb)
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
            guard let keychain = keychain else {
                handleError(.nilAddressManager, cb)
                return
            }
            let fromAddresses: [Address]
            do {
                fromAddresses = try from ?? keychain.get(cached: account)
            } catch {
                handleError(error, cb)
                return
            }
            let utxoIterator = utxoProvider.utxos(api: self, addresses: fromAddresses)
            UTXOHelper.getAll(iterator: utxoIterator) { res in
                switch res {
                case .success(let utxos):
                    self.getAvaxAssetID { res in
                        switch res {
                        case .success(let avaxAssetID):
                            let changeAddress = change ?? to
                            let fee = UInt64(self.info.txFee)
                            let inputs: [TransferableInput]
                            let outputs: [TransferableOutput]
                            do {
                                var aad = AssetAmountDestination(
                                    senders: fromAddresses,
                                    destinations: [to],
                                    changeAddresses: [changeAddress]
                                )
                                let feeAssetID = avaxAssetID
                                if assetID == feeAssetID {
                                    aad.assetAmounts[assetID] = AssetAmount(assetID: assetID, amount: amount, burn: fee)
                                } else {
                                    aad.assetAmounts[assetID] = AssetAmount(assetID: assetID, amount: amount, burn: 0)
                                    aad.assetAmounts[feeAssetID] = AssetAmount(assetID: feeAssetID, amount: 0, burn: fee)
                                }
                                let spendable = try UTXOHelper.getMinimumSpendable(aad: aad, utxos: utxos)
                                inputs = spendable.inputs
                                outputs = spendable.change + spendable.outputs
                            } catch {
                                self.handleError(error, cb)
                                return
                            }
                            let transaction: UnsignedAvalancheTransaction
                            do {
                                transaction = try BaseTransaction(
                                    networkID: self.networkID,
                                    blockchainID: self.info.blockchainID,
                                    outputs: outputs,
                                    inputs: inputs,
                                    memo: memo != nil ? memo!.data(using: .utf8)! : Data()
                                )
                            }
                            catch {
                                self.handleError(error, cb)
                                return
                            }
                            guard TransactionHelper.checkGooseEgg(
                                avax: avaxAssetID,
                                transaction: transaction
                            ) else {
                                self.handleError(TransactionBuilderError.gooseEggCheckError, cb)
                                return
                            }
                            self.signAndSend(transaction, with: fromAddresses, using: utxos) { res in
                                cb(res.map { transactionID in
                                    (txID: transactionID, change: changeAddress)
                                })
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
            guard let keychain = keychain else {
                handleError(.nilAddressManager, cb)
                return
            }
            let fromAddresses: [Address]
            do {
                fromAddresses = try from ?? keychain.get(cached: account)
            } catch {
                handleError(error, cb)
                return
            }
            let utxoIterator = utxoProvider.utxos(api: self, addresses: fromAddresses)
            UTXOHelper.getAll(iterator: utxoIterator) { res in
                switch res {
                case .success(let utxos):
                    self.getAvaxAssetID { res in
                        switch res {
                        case .success(let avaxAssetID):
                            let changeAddress: Address
                            do {
                                changeAddress = try change ?? keychain.newChange(for: account)
                            } catch {
                                self.handleError(error, cb)
                                return
                            }
                            let fee = UInt64(self.info.txFee)
                            let feeAssetID = avaxAssetID
                            var inputs = [TransferableInput]()
                            var transferableOutputs = [TransferableOutput]()
                            for output in outputs {
                                let (assetID, amount, to) = output
                                var aad = AssetAmountDestination(
                                    senders: fromAddresses,
                                    destinations: [to],
                                    changeAddresses: [changeAddress]
                                )
                                if assetID == feeAssetID {
                                    aad.assetAmounts[assetID] = AssetAmount(assetID: assetID, amount: amount, burn: fee)
                                } else {
                                    aad.assetAmounts[assetID] = AssetAmount(assetID: assetID, amount: amount, burn: 0)
                                    aad.assetAmounts[feeAssetID] = AssetAmount(assetID: feeAssetID, amount: 0, burn: fee)
                                }
                                do {
                                    let spendable = try UTXOHelper.getMinimumSpendable(aad: aad, utxos: utxos)
                                    inputs.append(contentsOf: spendable.inputs)
                                    transferableOutputs.append(contentsOf: spendable.change + spendable.outputs)
                                } catch {
                                    self.handleError(error, cb)
                                    return
                                }
                            }
                            let transaction: UnsignedAvalancheTransaction
                            do {
                                transaction = try BaseTransaction(
                                    networkID: self.networkID,
                                    blockchainID: self.info.blockchainID,
                                    outputs: transferableOutputs,
                                    inputs: inputs,
                                    memo: memo != nil ? memo!.data(using: .utf8)! : Data()
                                )
                            }
                            catch {
                                self.handleError(error, cb)
                                return
                            }
                            guard TransactionHelper.checkGooseEgg(
                                avax: avaxAssetID,
                                transaction: transaction
                            ) else {
                                self.handleError(TransactionBuilderError.gooseEggCheckError, cb)
                                return
                            }
                            self.signAndSend(transaction, with: fromAddresses, using: utxos) { res in
                                cb(res.map { transactionID in
                                    (txID: transactionID, change: changeAddress)
                                })
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
            guard let keychain = keychain else {
                handleError(.nilAddressManager, cb)
                return
            }
            let fromAddresses: [Address]
            do {
                fromAddresses = try from ?? keychain.get(cached: account)
            } catch {
                handleError(error, cb)
                return
            }
            let iterator = utxoProvider.utxos(api: self, addresses: fromAddresses)
            UTXOHelper.getAll(iterator: iterator) { res in
                switch res {
                case .success(let utxos):
                    self.getAvaxAssetID { res in
                        switch res {
                        case .success(let avaxAssetID):
                            let utxo = utxos.first { type(of: $0.output) == NFTTransferOutput.self }!
                            let changeAddress: Address
                            do {
                                changeAddress = try change ?? keychain.newChange(for: account)
                            } catch {
                                self.handleError(error, cb)
                                return
                            }
                            let fee = UInt64(self.info.txFee)
                            let feeAssetID = avaxAssetID
                            let (inputs, outputs): ([TransferableInput], [TransferableOutput])
                            do {
                                (inputs, outputs) = try self.getInputsOutputs(
                                    assetID: feeAssetID,
                                    from: fromAddresses,
                                    to: fromAddresses,
                                    change: [changeAddress],
                                    utxos: utxos,
                                    fee: fee
                                )
                            } catch {
                                self.handleError(error, cb)
                                return
                            }
                            let nftTransferOutput = utxo.output as! NFTTransferOutput
                            let addressIndices = nftTransferOutput.getAddressIndices(for: fromAddresses)
                            let nftTransferOperation: Operation
                            do {
                                nftTransferOperation = NFTTransferOperation(
                                    addressIndices: addressIndices,
                                    nftTransferOutput: try NFTTransferOperationOutput(
                                        groupID: nftTransferOutput.groupID,
                                        payload: nftTransferOutput.payload,
                                        locktime: Date(timeIntervalSince1970: 0),
                                        threshold: 1,
                                        addresses: [to]
                                    )
                                )
                            } catch {
                                self.handleError(error, cb)
                                return
                            }
                            let transferableOperation = TransferableOperation(
                                assetID: utxo.assetID,
                                utxoIDs: [
                                    UTXOID(
                                        transactionID: utxo.transactionID,
                                        utxoIndex: utxo.utxoIndex
                                    )
                                ],
                                transferOperation: nftTransferOperation
                            )
                            let transaction: UnsignedAvalancheTransaction
                            do {
                                transaction = try OperationTransaction(
                                    networkID: self.networkID,
                                    blockchainID: self.info.blockchainID,
                                    outputs: outputs,
                                    inputs: inputs,
                                    memo: memo,
                                    operations: [transferableOperation]
                                )
                            } catch {
                                self.handleError(error, cb)
                                return
                            }
                            guard TransactionHelper.checkGooseEgg(
                                avax: avaxAssetID,
                                transaction: transaction
                            ) else {
                                self.handleError(TransactionBuilderError.gooseEggCheckError, cb)
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
}

extension AvalancheCore {
    public var xChain: AvalancheXChainApi {
        return try! self.getAPI()
    }
    
    public func xChain(networkID: NetworkID, hrp: String, info: AvalancheXChainApi.Info) -> AvalancheXChainApi {
        return self.createAPI(networkID: networkID, hrp: hrp, info: info)
    }
}
