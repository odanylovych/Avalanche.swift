//
//  XChain+Transactions.swift
//  
//
//  Created by Ostap Danylovych on 10.02.2022.
//

import Foundation

extension AvalancheXChainApi {
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
    
    public func txCreateFixedCapAsset(
        name: String,
        symbol: String,
        denomination: UInt8? = nil,
        initialHolders: [(address: Address, amount: UInt64)],
        from: [Address]? = nil,
        change: Address? = nil,
        memo: Data = Data(),
        account: Account,
        _ cb: @escaping ApiCallback<(assetID: AssetID, change: Address)>
    ) {
        withTransactionData(for: account, from: from, change: change) { res in
            switch res {
            case .success((let utxos, let fromAddresses, let changeAddress, let avaxAssetID, let blockchainID)):
                self.getCreationTxFee { res in
                    switch res {
                    case .success(let fee):
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
                                blockchainID: blockchainID,
                                outputs: outputs,
                                inputs: inputs,
                                memo: memo,
                                name: name,
                                symbol: symbol,
                                denomination: denomination ?? 0,
                                initialStates: initialStates
                            )
                        } catch {
                            self.handleError(error, cb)
                            return
                        }
                        guard transaction.checkGooseEgg(avax: avaxAssetID, outputTotal: fee) else {
                            self.handleError(TransactionBuilderError.gooseEggCheckError, cb)
                            return
                        }
                        self.signAndSend(transaction) { res in
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
    
    public func txMint(
        amount: UInt64,
        assetID: AssetID,
        to: Address,
        from: [Address]? = nil,
        change: Address? = nil,
        memo: Data = Data(),
        account: Account,
        _ cb: @escaping ApiCallback<(txID: TransactionID, change: Address)>
    ) {
        withTransactionData(for: account, from: from, change: change) { res in
            switch res {
            case .success((let utxos, let fromAddresses, let changeAddress, let avaxAssetID, let blockchainID)):
                self.getTxFee { res in
                    switch res {
                    case .success(let fee):
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
                        let transaction: OperationTransaction
                        do {
                            transaction = try OperationTransaction(
                                networkID: self.networkID,
                                blockchainID: blockchainID,
                                outputs: outputs,
                                inputs: inputs,
                                memo: memo,
                                operations: [transferableOperation]
                            )
                        } catch {
                            self.handleError(error, cb)
                            return
                        }
                        guard transaction.checkGooseEgg(avax: avaxAssetID) else {
                            self.handleError(TransactionBuilderError.gooseEggCheckError, cb)
                            return
                        }
                        self.signAndSend(transaction) { res in
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
    
    public func txCreateVariableCapAsset(
        name: String,
        symbol: String,
        denomination: UInt8? = nil,
        minterSets: [(minters: [Address], threshold: UInt32)],
        from: [Address]? = nil,
        change: Address? = nil,
        memo: Data = Data(),
        account: Account,
        _ cb: @escaping ApiCallback<(assetID: AssetID, change: Address)>
    ) {
        withTransactionData(for: account, from: from, change: change) { res in
            switch res {
            case .success((let utxos, let fromAddresses, let changeAddress, let avaxAssetID, let blockchainID)):
                self.getCreationTxFee { res in
                    switch res {
                    case .success(let fee):
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
                                blockchainID: blockchainID,
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
                        guard transaction.checkGooseEgg(avax: avaxAssetID, outputTotal: fee) else {
                            self.handleError(TransactionBuilderError.gooseEggCheckError, cb)
                            return
                        }
                        self.signAndSend(transaction) { res in
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
    
    public func txCreateNFTAsset(
        name: String,
        symbol: String,
        minterSets: [(minters: [Address], threshold: UInt32)],
        from: [Address]? = nil,
        change: Address? = nil,
        memo: Data = Data(),
        account: Account,
        _ cb: @escaping ApiCallback<(assetID: AssetID, change: Address)>
    ) {
        withTransactionData(for: account, from: from, change: change) { res in
            switch res {
            case .success((let utxos, let fromAddresses, let changeAddress, let avaxAssetID, let blockchainID)):
                self.getCreationTxFee { res in
                    switch res {
                    case .success(let fee):
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
                        let transaction: CreateAssetTransaction
                        do {
                            transaction = try CreateAssetTransaction(
                                networkID: self.networkID,
                                blockchainID: blockchainID,
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
                        guard transaction.checkGooseEgg(avax: avaxAssetID, outputTotal: fee) else {
                            self.handleError(TransactionBuilderError.gooseEggCheckError, cb)
                            return
                        }
                        self.signAndSend(transaction) { res in
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
    
    public func txMintNFT(
        assetID: AssetID,
        payload: String,
        to: Address,
        from: [Address]? = nil,
        change: Address? = nil,
        memo: Data = Data(),
        account: Account,
        _ cb: @escaping ApiCallback<(txID: TransactionID, change: Address)>
    ) {
        withTransactionData(for: account, from: from, change: change) { res in
            switch res {
            case .success((let utxos, let fromAddresses, let changeAddress, let avaxAssetID, let blockchainID)):
                self.getTxFee { res in
                    switch res {
                    case .success(let fee):
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
                        let transaction: OperationTransaction
                        do {
                            transaction = try OperationTransaction(
                                networkID: self.networkID,
                                blockchainID: blockchainID,
                                outputs: outputs,
                                inputs: inputs,
                                memo: memo,
                                operations: [transferableOperation]
                            )
                        } catch {
                            self.handleError(error, cb)
                            return
                        }
                        guard transaction.checkGooseEgg(avax: avaxAssetID) else {
                            self.handleError(TransactionBuilderError.gooseEggCheckError, cb)
                            return
                        }
                        self.signAndSend(transaction) { res in
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
    
    public func txExport(
        to: Address,
        amount: UInt64,
        assetID: AssetID,
        from: [Address]? = nil,
        change: Address? = nil,
        memo: Data = Data(),
        account: Account,
        _ cb: @escaping ApiCallback<(txID: TransactionID, change: Address)>
    ) {
        withTransactionData(for: account, from: from, change: change) { res in
            switch res {
            case .success((let utxos, let fromAddresses, let changeAddress, let avaxAssetID, let blockchainID)):
                self.getTxFee { res in
                    switch res {
                    case .success(let fee):
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
                        self.blockchainIDs(ChainID(to.chainId)) { res in
                            switch res {
                            case .success(let destinationChain):
                                let transaction: ExportTransaction
                                do {
                                    transaction = try ExportTransaction(
                                        networkID: self.networkID,
                                        blockchainID: blockchainID,
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
                                guard transaction.checkGooseEgg(avax: avaxAssetID) else {
                                    self.handleError(TransactionBuilderError.gooseEggCheckError, cb)
                                    return
                                }
                                self.signAndSend(transaction) { res in
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
            case .failure(let error):
                self.handleError(error, cb)
            }
        }
    }
    
    public func txImport<A: AvalancheTransactionApi>(
        to: Address,
        source api: A,
        memo: Data = Data(),
        account: Account,
        _ cb: @escaping ApiCallback<TransactionID>
    ) {
        api.getBlockchainID { res in
            switch res {
            case .success(let sourceChain):
                self.withTransactionData(for: account, sourceChain: sourceChain) { res in
                    switch res {
                    case .success((let utxos, let fromAddresses, let changeAddress, let avaxAssetID, let blockchainID)):
                        self.getTxFee { res in
                            switch res {
                            case .success(var fee):
                                let feeAssetID = avaxAssetID
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
                                let transaction: ImportTransaction
                                do {
                                    transaction = try ImportTransaction(
                                        networkID: self.networkID,
                                        blockchainID: blockchainID,
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
                                guard transaction.checkGooseEgg(avax: avaxAssetID) else {
                                    self.handleError(TransactionBuilderError.gooseEggCheckError, cb)
                                    return
                                }
                                self.signAndSend(transaction, source: api, cb)
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
    
    public func txSend(
        amount: UInt64,
        assetID: AssetID,
        to: Address,
        memo: String? = nil,
        from: [Address]? = nil,
        change: Address? = nil,
        account: Account,
        _ cb: @escaping ApiCallback<(txID: TransactionID, change: Address)>
    ) {
        withTransactionData(for: account, from: from, change: change) { res in
            switch res {
            case .success((let utxos, let fromAddresses, let changeAddress, let avaxAssetID, let blockchainID)):
                self.getTxFee { res in
                    switch res {
                    case .success(let fee):
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
                            outputs = spendable.outputs + spendable.change
                        } catch {
                            self.handleError(error, cb)
                            return
                        }
                        let transaction: BaseTransaction
                        do {
                            transaction = try BaseTransaction(
                                networkID: self.networkID,
                                blockchainID: blockchainID,
                                outputs: outputs,
                                inputs: inputs,
                                memo: memo != nil ? memo!.data(using: .utf8)! : Data()
                            )
                        }
                        catch {
                            self.handleError(error, cb)
                            return
                        }
                        guard transaction.checkGooseEgg(avax: avaxAssetID) else {
                            self.handleError(TransactionBuilderError.gooseEggCheckError, cb)
                            return
                        }
                        self.signAndSend(transaction) { res in
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
    
    public func txSendMultiple(
        outputs: [(assetID: AssetID, amount: UInt64, to: Address)],
        from: [Address]? = nil,
        change: Address? = nil,
        memo: String? = nil,
        account: Account,
        _ cb: @escaping ApiCallback<(txID: TransactionID, change: Address)>
    ) {
        withTransactionData(for: account, from: from, change: change) { res in
            switch res {
            case .success((let utxos, let fromAddresses, let changeAddress, let avaxAssetID, let blockchainID)):
                self.getTxFee { res in
                    switch res {
                    case .success(let fee):
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
                        let transaction: BaseTransaction
                        do {
                            transaction = try BaseTransaction(
                                networkID: self.networkID,
                                blockchainID: blockchainID,
                                outputs: transferableOutputs,
                                inputs: inputs,
                                memo: memo != nil ? memo!.data(using: .utf8)! : Data()
                            )
                        }
                        catch {
                            self.handleError(error, cb)
                            return
                        }
                        guard transaction.checkGooseEgg(avax: avaxAssetID) else {
                            self.handleError(TransactionBuilderError.gooseEggCheckError, cb)
                            return
                        }
                        self.signAndSend(transaction) { res in
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
    
    public func txSendNFT(
        assetID: AssetID,
        groupID: UInt32,
        to: Address,
        from: [Address]? = nil,
        change: Address? = nil,
        memo: Data = Data(),
        account: Account,
        _ cb: @escaping ApiCallback<TransactionID>
    ) {
        withTransactionData(for: account, from: from, change: change) { res in
            switch res {
            case .success((let utxos, let fromAddresses, let changeAddress, let avaxAssetID, let blockchainID)):
                self.getTxFee { res in
                    switch res {
                    case .success(let fee):
                        let utxo = utxos.first { type(of: $0.output) == NFTTransferOutput.self }!
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
                        let transaction: OperationTransaction
                        do {
                            transaction = try OperationTransaction(
                                networkID: self.networkID,
                                blockchainID: blockchainID,
                                outputs: outputs,
                                inputs: inputs,
                                memo: memo,
                                operations: [transferableOperation]
                            )
                        } catch {
                            self.handleError(error, cb)
                            return
                        }
                        guard transaction.checkGooseEgg(avax: avaxAssetID) else {
                            self.handleError(TransactionBuilderError.gooseEggCheckError, cb)
                            return
                        }
                        self.signAndSend(transaction, cb)
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
