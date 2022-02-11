//
//  TransactionHelper.swift
//  
//
//  Created by Ostap Danylovych on 29.11.2021.
//

import Foundation
import BigInt

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
