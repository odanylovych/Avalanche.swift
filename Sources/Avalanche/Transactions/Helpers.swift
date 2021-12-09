//
//  Helpers.swift
//  
//
//  Created by Ostap Danylovych on 29.11.2021.
//

import Foundation

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
    private let burn: UInt64
    public let change: UInt64
    private let spent: UInt64
    public let finished: Bool
    
    public init(
        assetID: AssetID,
        amount: UInt64,
        burn: UInt64,
        change: UInt64 = 0,
        spent: UInt64 = 0,
        finished: Bool = false
    ) {
        self.assetID = assetID
        self.amount = amount
        self.burn = burn
        self.change = change
        self.spent = spent
        self.finished = finished
    }
    
    public func spend(amount: UInt64) -> AssetAmount {
        let spent = spent + amount
        let total = self.amount + burn
        var change = change
        var finished = finished
        if spent >= total {
            change = spent - total
            finished = true
        }
        return AssetAmount(
            assetID: assetID,
            amount: self.amount,
            burn: burn,
            change: change,
            spent: spent,
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
                               assetID: AssetID) -> UInt64 {
        getInputTotal(inputs, assetID: assetID) - getOutputTotal(outputs, assetID: assetID)
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
