//
//  Helpers.swift
//  
//
//  Created by Ostap Danylovych on 29.11.2021.
//

import Foundation
import BigInt

public struct AssetAmountDestination {
    public let senders: [Address]
    public let destinations: [Address]
    public let changeAddresses: [Address]
    public var assetAmounts = [AssetID: AssetAmount]()
    
    public var canComplete: Bool {
        assetAmounts.values.allSatisfy { $0.finished }
    }
    
    public init(senders: [Address], destinations: [Address], changeAddresses: [Address]) {
        self.senders = senders
        self.destinations = destinations
        self.changeAddresses = changeAddresses
    }
}

public struct AssetAmount {
    public let assetID: AssetID
    public let amount: UInt64
    public let burn: UInt64
    public let change: UInt64
    public let spent: UInt64
    public let lockSpent: UInt64
    public let lockChange: Bool
    public let finished: Bool
    
    public init(
        assetID: AssetID,
        amount: UInt64,
        burn: UInt64,
        change: UInt64 = 0,
        spent: UInt64 = 0,
        lockSpent: UInt64 = 0,
        lockChange: Bool = false,
        finished: Bool = false
    ) {
        self.assetID = assetID
        self.amount = amount
        self.burn = burn
        self.change = change
        self.spent = spent
        self.lockSpent = lockSpent
        self.lockChange = lockChange
        self.finished = finished
    }
    
    public func spend(amount: UInt64, locked: Bool = false) -> AssetAmount {
        let spent = spent + amount
        var lockSpent = lockSpent
        if locked {
            lockSpent = lockSpent + amount
        }
        let total = self.amount + burn
        var change = change
        var finished = finished
        var lockChange = lockChange
        if spent >= total {
            change = spent - total
            if locked {
                lockChange = true
            }
            finished = true
        }
        return AssetAmount(
            assetID: assetID,
            amount: self.amount,
            burn: burn,
            change: change,
            spent: spent,
            lockSpent: lockSpent,
            lockChange: lockChange,
            finished: finished
        )
    }
}

public struct UTXOHelper {
    private static func getUtxos(
        iterator: AvalancheUtxoProviderIterator,
        limit: UInt32? = nil,
        sourceChain: BlockchainID? = nil,
        all: [UTXO],
        _ cb: @escaping ApiCallback<[UTXO]>
    ) {
        iterator.next(limit: limit, sourceChain: sourceChain) { res in
            switch res {
            case .success(let (utxos, iterator)):
                guard let iterator = iterator else {
                    cb(.success(all + utxos))
                    return
                }
                self.getUtxos(iterator: iterator, limit: limit, sourceChain: sourceChain, all: all + utxos, cb)
            case .failure(let error):
                cb(.failure(error))
            }
        }
    }
    
    public static func getAll(
        iterator: AvalancheUtxoProviderIterator,
        limit: UInt32? = nil,
        sourceChain: BlockchainID? = nil,
        _ cb: @escaping ApiCallback<[UTXO]>
    ) {
        getUtxos(iterator: iterator, limit: limit, sourceChain: sourceChain, all: [], cb)
    }
    
    public static func getMinimumSpendable(
        aad: AssetAmountDestination,
        locktime: Date = Date(timeIntervalSince1970: 0),
        threshold: UInt32 = 1,
        utxos: [UTXO]
    ) throws -> (
        inputs: [TransferableInput],
        outputs: [TransferableOutput],
        change: [TransferableOutput]
    ) {
        var aad = aad
        var inputs = [TransferableInput]()
        var outputTypes = [AssetID: Output.Type]()
        for utxo in utxos.filter({
            type(of: $0.output) == SECP256K1TransferOutput.self
            && aad.assetAmounts.keys.contains($0.assetID)
            && $0.output.getAddressIndices(for: aad.senders).count == $0.output.threshold
        }) {
            let output = utxo.output as! SECP256K1TransferOutput
            let addressIndices = output.getAddressIndices(for: aad.senders)
            let assetAmount = aad.assetAmounts[utxo.assetID]!
            if addressIndices.count == output.threshold && !assetAmount.finished {
                outputTypes[utxo.assetID] = type(of: output)
                aad.assetAmounts[utxo.assetID] = assetAmount.spend(amount: output.amount)
                inputs.append(TransferableInput(
                    transactionID: utxo.transactionID,
                    utxoIndex: utxo.utxoIndex,
                    assetID: utxo.assetID,
                    input: try SECP256K1TransferInput(amount: output.amount, addressIndices: addressIndices)
                ))
            }
            if aad.canComplete {
                break
            }
        }
        if !aad.canComplete {
            throw TransactionBuilderError.insufficientFunds
        }
        let outputs = try aad.assetAmounts.values.filter { $0.amount > 0 }.map {
            TransferableOutput(
                assetID: $0.assetID,
                output: try outputTypes[$0.assetID]!.init(
                    amount: $0.amount,
                    locktime: locktime,
                    threshold: threshold,
                    addresses: aad.destinations
                )
            )
        }
        let change = try aad.assetAmounts.values.filter { $0.change > 0 }.map {
            TransferableOutput(
                assetID: $0.assetID,
                output: try outputTypes[$0.assetID]!.init(
                    amount: $0.change,
                    locktime: Date(timeIntervalSince1970: 0),
                    threshold: 1,
                    addresses: aad.changeAddresses
                )
            )
        }
        return (inputs, outputs, change)
    }
    
    public static func getMinimumSpendablePChain(
        aad: AssetAmountDestination,
        asOf: Date = Date(),
        locktime: Date = Date(timeIntervalSince1970: 0),
        threshold: UInt32 = 1,
        stakeable: Bool = false,
        utxos: [UTXO]
    ) throws -> (
        inputs: [TransferableInput],
        outputs: [TransferableOutput],
        change: [TransferableOutput]
    ) {
        var utxos = stakeable ? utxos : utxos.filter {
            type(of: $0.output) != StakeableLockedOutput.self
            || ($0.output as! StakeableLockedOutput).locktime < asOf
        }
        if stakeable {
            var tempUTXOs = utxos.filter { type(of: $0.output) == StakeableLockedOutput.self }
            tempUTXOs.sort(by: { utxo1, utxo2 in
                let output1 = utxo1.output as! StakeableLockedOutput
                let output2 = utxo2.output as! StakeableLockedOutput
                return output1.locktime < output2.locktime
            })
            tempUTXOs.append(contentsOf: utxos.filter { type(of: $0.output) == SECP256K1TransferOutput.self })
            utxos = tempUTXOs
        }
        var aad = aad
        var inputs = [TransferableInput]()
        var outputs = [TransferableOutput]()
        var change = [TransferableOutput]()
        var outputMap = [AssetID: (lockedStakeable: [StakeableLockedOutput], unlocked: [Output])]()
        let getAmount = { output in
            type(of: output) == SECP256K1TransferOutput.self
            ? (output as! SECP256K1TransferOutput).amount
            : ((output as! StakeableLockedOutput).transferableOutput.output as! SECP256K1TransferOutput).amount
        }
        for utxo in utxos.filter({
            (type(of: $0.output) == SECP256K1TransferOutput.self || type(of: $0.output) == StakeableLockedOutput.self)
            && aad.assetAmounts.keys.contains($0.assetID)
            && $0.output.getAddressIndices(for: aad.senders).count == $0.output.threshold
        }) {
            let assetAmount = aad.assetAmounts[utxo.assetID]!
            if assetAmount.finished {
                continue
            }
            if !outputMap.keys.contains(utxo.assetID) {
                outputMap[utxo.assetID] = (lockedStakeable: [], unlocked: [])
            }
            let amount = getAmount(utxo.output)
            var input: Input = try SECP256K1TransferInput(
                amount: amount,
                addressIndices: utxo.output.getAddressIndices(for: aad.senders)
            )
            var locked = false
            if type(of: utxo.output) == StakeableLockedOutput.self {
                let output = utxo.output as! StakeableLockedOutput
                if output.locktime > asOf {
                    input = StakeableLockedInput(
                        locktime: output.locktime,
                        transferableInput: TransferableInput(
                            transactionID: utxo.transactionID,
                            utxoIndex: utxo.utxoIndex,
                            assetID: utxo.assetID,
                            input: input
                        )
                    )
                    locked = true
                }
            }
            aad.assetAmounts[utxo.assetID] = assetAmount.spend(amount: amount, locked: locked)
            if locked {
                outputMap[utxo.assetID]!.lockedStakeable.append(utxo.output as! StakeableLockedOutput)
            } else {
                outputMap[utxo.assetID]!.unlocked.append(utxo.output)
            }
            inputs.append(TransferableInput(
                transactionID: utxo.transactionID,
                utxoIndex: utxo.utxoIndex,
                assetID: utxo.assetID,
                input: input
            ))
        }
        if !aad.canComplete {
            throw TransactionBuilderError.insufficientFunds
        }
        for assetAmount in aad.assetAmounts.values {
            let lockedChange = assetAmount.lockChange ? assetAmount.change : 0
            if let lockedOutputs = outputMap[assetAmount.assetID]?.lockedStakeable {
                for (index, lockedOutput) in lockedOutputs.enumerated() {
                    let output = lockedOutput.transferableOutput.output
                    var outputAmountRemaining = getAmount(output)
                    if index == lockedOutputs.count - 1 && lockedChange > 0 {
                        outputAmountRemaining = outputAmountRemaining - lockedChange
                        change.append(TransferableOutput(
                            assetID: assetAmount.assetID,
                            output: try StakeableLockedOutput(
                                locktime: lockedOutput.locktime,
                                transferableOutput: TransferableOutput(
                                    assetID: assetAmount.assetID,
                                    output: type(of: output).init(
                                        amount: lockedChange,
                                        locktime: output.locktime,
                                        threshold: output.threshold,
                                        addresses: output.addresses
                                    )
                                )
                            )
                        ))
                    }
                    outputs.append(TransferableOutput(
                        assetID: assetAmount.assetID,
                        output: try StakeableLockedOutput(
                            locktime: lockedOutput.locktime,
                            transferableOutput: TransferableOutput(
                                assetID: assetAmount.assetID,
                                output: type(of: output).init(
                                    amount: outputAmountRemaining,
                                    locktime: output.locktime,
                                    threshold: output.threshold,
                                    addresses: output.addresses
                                )
                            )
                        )
                    ))
                }
            }
            let unlockedChange = assetAmount.lockChange ? 0 : assetAmount.change
            if unlockedChange > 0 {
                change.append(TransferableOutput(
                    assetID: assetAmount.assetID,
                    output: try SECP256K1TransferOutput(
                        amount: unlockedChange,
                        locktime: Date(timeIntervalSince1970: 0),
                        threshold: 1,
                        addresses: aad.changeAddresses
                    )
                ))
            }
            let totalUnlockedSpent = assetAmount.spent - assetAmount.lockSpent
            let totalUnlockedAvailable = totalUnlockedSpent - assetAmount.burn
            let unlockedAmount = totalUnlockedAvailable - unlockedChange
            if unlockedAmount > 0 {
                outputs.append(TransferableOutput(
                    assetID: assetAmount.assetID,
                    output: try SECP256K1TransferOutput(
                        amount: unlockedAmount,
                        locktime: locktime,
                        threshold: threshold,
                        addresses: aad.destinations
                    )
                ))
            }
        }
        return (inputs, outputs, change)
    }
}

public struct TransactionHelper {
    public static func getInputTotal(_ inputs: [TransferableInput],
                                     assetID: AssetID) -> UInt64 {
        inputs.filter {
            type(of: $0.input) == SECP256K1TransferInput.self
            && $0.assetID == assetID
        }.reduce(0) { total, input in
            total + (input.input as! SECP256K1TransferInput).amount
        }
    }
    
    public static func getOutputTotal(_ outputs: [TransferableOutput],
                                      assetID: AssetID) -> UInt64 {
        outputs.filter {
            type(of: $0.output) == SECP256K1TransferOutput.self
            && $0.assetID == assetID
        }.reduce(0) { total, output in
            total + (output.output as! SECP256K1TransferOutput).amount
        }
    }
    
    public static func getBurn(_ inputs: [TransferableInput],
                               _ outputs: [TransferableOutput],
                               assetID: AssetID) -> BigInt {
        let inputTotal = BigInt(getInputTotal(inputs, assetID: assetID))
        let outputTotal = BigInt(getOutputTotal(outputs, assetID: assetID))
        return inputTotal - outputTotal
    }
    
    public static func checkGooseEgg(
        avax assetID: AssetID,
        transaction: UnsignedAvalancheTransaction,
        outputTotal: UInt64? = nil
    ) -> Bool {
        let transaction = transaction as! BaseTransaction
        let outputTotal = outputTotal ?? getOutputTotal(transaction.outputs, assetID: assetID)
        let fee = getBurn(transaction.inputs, transaction.outputs, assetID: assetID)
        return fee <= 1_000_000_000 * 10 || fee <= outputTotal
    }
}
