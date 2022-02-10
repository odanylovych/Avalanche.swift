//
//  PChain+Transactions.swift
//  
//
//  Created by Ostap Danylovych on 10.02.2022.
//

import Foundation

extension AvalanchePChainApi {
    public func txAddDelegator(
        nodeID: NodeID,
        startTime: Date,
        endTime: Date,
        stakeAmount: UInt64,
        reward: Address,
        from: [Address]? = nil,
        to: [Address]? = nil,
        change: Address? = nil,
        memo: Data = Data(),
        account: Account,
        _ cb: @escaping ApiCallback<(txID: TransactionID, change: Address)>
    ) {
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
                self.getStakingAssetID { res in
                    switch res {
                    case .success(let avaxAssetID):
                        let changeAddress: Address
                        do {
                            changeAddress = try change ?? keychain.newChange(for: account)
                        } catch {
                            self.handleError(error, cb)
                            return
                        }
                        let inputs: [TransferableInput]
                        let outputs: [TransferableOutput]
                        let stakeOutputs: [TransferableOutput]
                        do {
                            var aad = AssetAmountDestination(
                                senders: fromAddresses,
                                destinations: to ?? fromAddresses,
                                changeAddresses: [changeAddress]
                            )
                            aad.assetAmounts[avaxAssetID] = AssetAmount(
                                assetID: avaxAssetID,
                                amount: stakeAmount,
                                burn: 0
                            )
                            let spendable = try UTXOHelper.getMinimumSpendablePChain(aad: aad, stakeable: true, utxos: utxos)
                            inputs = spendable.inputs
                            outputs = spendable.change
                            stakeOutputs = spendable.outputs
                        } catch {
                            self.handleError(error, cb)
                            return
                        }
                        let transaction: UnsignedAvalancheTransaction
                        do {
                            transaction = try AddDelegatorTransaction(
                                networkID: self.networkID,
                                blockchainID: self.info.blockchainID,
                                outputs: outputs,
                                inputs: inputs,
                                memo: memo,
                                validator: Validator(
                                    nodeID: nodeID,
                                    startTime: startTime,
                                    endTime: endTime,
                                    weight: stakeAmount
                                ),
                                stake: Stake(lockedOutputs: stakeOutputs),
                                rewardsOwner: SECP256K1OutputOwners(
                                    locktime: Date(timeIntervalSince1970: 0),
                                    threshold: 1,
                                    addresses: [reward]
                                )
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
    
    public func txAddValidator(
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
        account: Account,
        _ cb: @escaping ApiCallback<(txID: TransactionID, change: Address)>
    ) {
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
                self.getStakingAssetID { res in
                    switch res {
                    case .success(let avaxAssetID):
                        let changeAddress: Address
                        do {
                            changeAddress = try change ?? keychain.newChange(for: account)
                        } catch {
                            self.handleError(error, cb)
                            return
                        }
                        let inputs: [TransferableInput]
                        let outputs: [TransferableOutput]
                        let stakeOutputs: [TransferableOutput]
                        do {
                            var aad = AssetAmountDestination(
                                senders: fromAddresses,
                                destinations: to ?? fromAddresses,
                                changeAddresses: [changeAddress]
                            )
                            aad.assetAmounts[avaxAssetID] = AssetAmount(
                                assetID: avaxAssetID,
                                amount: stakeAmount,
                                burn: 0
                            )
                            let spendable = try UTXOHelper.getMinimumSpendablePChain(aad: aad, stakeable: true, utxos: utxos)
                            inputs = spendable.inputs
                            outputs = spendable.change
                            stakeOutputs = spendable.outputs
                        } catch {
                            self.handleError(error, cb)
                            return
                        }
                        let transaction: UnsignedAvalancheTransaction
                        do {
                            transaction = try AddValidatorTransaction(
                                networkID: self.networkID,
                                blockchainID: self.info.blockchainID,
                                outputs: outputs,
                                inputs: inputs,
                                memo: memo,
                                validator: Validator(
                                    nodeID: nodeID,
                                    startTime: startTime,
                                    endTime: endTime,
                                    weight: stakeAmount
                                ),
                                stake: Stake(lockedOutputs: stakeOutputs),
                                rewardsOwner: SECP256K1OutputOwners(
                                    locktime: Date(timeIntervalSince1970: 0),
                                    threshold: 1,
                                    addresses: [reward]
                                ),
                                shares: UInt32(delegationFeeRate * 10_000)
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
                        handleError(error, cb)
                    }
                }
            case .failure(let error):
                handleError(error, cb)
            }
        }
    }
    
    public func txAddSubnetValidator(
        nodeID: NodeID,
        subnetID: BlockchainID,
        startTime: Date,
        endTime: Date,
        weight: UInt64,
        from: [Address]? = nil,
        change: Address? = nil,
        memo: Data = Data(),
        account: Account,
        _ cb: @escaping ApiCallback<(txID: TransactionID, change: Address)>
    ) {
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
                self.getStakingAssetID { res in
                    switch res {
                    case .success(let avaxAssetID):
                        let changeAddress: Address
                        do {
                            changeAddress = try change ?? keychain.newChange(for: account)
                        } catch {
                            self.handleError(error, cb)
                            return
                        }
                        let inputs: [TransferableInput]
                        let outputs: [TransferableOutput]
                        do {
                            var aad = AssetAmountDestination(
                                senders: fromAddresses,
                                destinations: fromAddresses,
                                changeAddresses: [changeAddress]
                            )
                            aad.assetAmounts[avaxAssetID] = AssetAmount(
                                assetID: avaxAssetID,
                                amount: weight,
                                burn: 0
                            )
                            let spendable = try UTXOHelper.getMinimumSpendablePChain(aad: aad, stakeable: true, utxos: utxos)
                            inputs = spendable.inputs
                            outputs = spendable.outputs + spendable.change
                        } catch {
                            self.handleError(error, cb)
                            return
                        }
                        let transaction: UnsignedAvalancheTransaction
                        do {
                            transaction = try AddSubnetValidatorTransaction(
                                networkID: self.networkID,
                                blockchainID: self.info.blockchainID,
                                outputs: outputs,
                                inputs: inputs,
                                memo: memo,
                                validator: Validator(
                                    nodeID: nodeID,
                                    startTime: startTime,
                                    endTime: endTime,
                                    weight: weight
                                ),
                                subnetID: subnetID,
                                subnetAuth: SubnetAuth(signatureIndices: []) // TODO: signatureIndices
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
                        handleError(error, cb)
                    }
                }
            case .failure(let error):
                handleError(error, cb)
            }
        }
        fatalError("Not implemented")
    }
    
    public func txCreateSubnet(
        controlKeys: [Address],
        threshold: UInt32,
        from: [Address]? = nil,
        change: Address? = nil,
        memo: Data = Data(),
        account: Account,
        _ cb: @escaping ApiCallback<(txID: TransactionID, change: Address)>
    ) {
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
                self.getStakingAssetID { res in
                    switch res {
                    case .success(let avaxAssetID):
                        let changeAddress: Address
                        do {
                            changeAddress = try change ?? keychain.newChange(for: account)
                        } catch {
                            self.handleError(error, cb)
                            return
                        }
                        let inputs: [TransferableInput]
                        let outputs: [TransferableOutput]
                        let fee = UInt64(self.info.creationTxFee)
                        do {
                            var aad = AssetAmountDestination(
                                senders: fromAddresses,
                                destinations: fromAddresses,
                                changeAddresses: [changeAddress]
                            )
                            aad.assetAmounts[avaxAssetID] = AssetAmount(
                                assetID: avaxAssetID,
                                amount: 0,
                                burn: fee
                            )
                            let spendable = try UTXOHelper.getMinimumSpendablePChain(aad: aad, utxos: utxos)
                            inputs = spendable.inputs
                            outputs = spendable.outputs + spendable.change
                        } catch {
                            self.handleError(error, cb)
                            return
                        }
                        let transaction: UnsignedAvalancheTransaction
                        do {
                            transaction = try CreateSubnetTransaction(
                                networkID: self.networkID,
                                blockchainID: self.info.blockchainID,
                                outputs: outputs,
                                inputs: inputs,
                                memo: memo,
                                rewardsOwner: SECP256K1OutputOwners(
                                    locktime: Date(timeIntervalSince1970: 0),
                                    threshold: threshold,
                                    addresses: fromAddresses
                                )
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
                                (txID: transactionID, change: changeAddress)
                            })
                        }
                    case .failure(let error):
                        handleError(error, cb)
                    }
                }
            case .failure(let error):
                handleError(error, cb)
            }
        }
    }
    
    public func txExportAVAX(
        to: Address,
        amount: UInt64,
        from: [Address]? = nil,
        change: Address? = nil,
        memo: Data = Data(),
        account: Account,
        _ cb: @escaping ApiCallback<(txID: TransactionID, change: Address)>
    ) {
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
                self.getStakingAssetID { res in
                    switch res {
                    case .success(let avaxAssetID):
                        let changeAddress: Address
                        do {
                            changeAddress = try change ?? keychain.newChange(for: account)
                        } catch {
                            self.handleError(error, cb)
                            return
                        }
                        let inputs: [TransferableInput]
                        let outputs: [TransferableOutput]
                        let exportOutputs: [TransferableOutput]
                        let fee = UInt64(self.info.txFee)
                        do {
                            var aad = AssetAmountDestination(
                                senders: fromAddresses,
                                destinations: [to],
                                changeAddresses: [changeAddress]
                            )
                            aad.assetAmounts[avaxAssetID] = AssetAmount(
                                assetID: avaxAssetID,
                                amount: amount,
                                burn: fee
                            )
                            let spendable = try UTXOHelper.getMinimumSpendablePChain(aad: aad, utxos: utxos)
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
                            transaction = try PChainExportTransaction(
                                networkID: self.networkID,
                                blockchainID: self.info.blockchainID,
                                outputs: outputs,
                                inputs: inputs,
                                memo: memo,
                                destinationChain: destinationChain,
                                transferableOutputs: exportOutputs
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
                        handleError(error, cb)
                    }
                }
            case .failure(let error):
                handleError(error, cb)
            }
        }
    }
    
    public func txImportAVAX(
        from: [Address]? = nil,
        to: Address,
        change: Address? = nil,
        source: BlockchainID,
        memo: Data = Data(),
        account: Account,
        _ cb: @escaping ApiCallback<(txID: TransactionID, change: Address)>
    ) {
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
        UTXOHelper.getAll(iterator: iterator, sourceChain: source) { res in
            switch res {
            case .success(let utxos):
                self.getStakingAssetID { res in
                    switch res {
                    case .success(let avaxAssetID):
                        let changeAddress: Address
                        do {
                            changeAddress = try keychain.newChange(for: account)
                        } catch {
                            self.handleError(error, cb)
                            return
                        }
                        var fee = UInt64(self.info.txFee)
                        var feePaid: UInt64 = 0
                        var importInputs = [TransferableInput]()
                        var outputs = [TransferableOutput]()
                        for utxo in utxos.filter({ type(of: $0.output) == SECP256K1TransferOutput.self }) {
                            let output = utxo.output as! SECP256K1TransferOutput
                            var inFeeAmount = output.amount
                            if fee > 0 && feePaid < fee && utxo.assetID == avaxAssetID {
                                feePaid += inFeeAmount
                                if feePaid >= fee {
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
                                var aad = AssetAmountDestination(
                                    senders: fromAddresses,
                                    destinations: [to],
                                    changeAddresses: [changeAddress]
                                )
                                aad.assetAmounts[avaxAssetID] = AssetAmount(
                                    assetID: avaxAssetID,
                                    amount: 0,
                                    burn: fee
                                )
                                let spendable = try UTXOHelper.getMinimumSpendablePChain(aad: aad, utxos: utxos)
                                inputs = spendable.inputs
                                outputs = spendable.outputs + spendable.change
                            } catch {
                                self.handleError(error, cb)
                                return
                            }
                        }
                        let transaction: UnsignedAvalancheTransaction
                        do {
                            transaction = try PChainImportTransaction(
                                networkID: self.networkID,
                                blockchainID: self.info.blockchainID,
                                outputs: outputs,
                                inputs: inputs,
                                memo: memo,
                                sourceChain: source,
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
