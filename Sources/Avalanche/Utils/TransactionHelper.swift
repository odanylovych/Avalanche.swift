//
//  TransactionHelper.swift
//  
//
//  Created by Ostap Danylovych on 29.11.2021.
//

import Foundation
import BigInt

extension BaseTransaction {
    public func getInputTotal(assetID: AssetID) -> UInt64 {
        inputs.filter {
            type(of: $0.input) == SECP256K1TransferInput.self
            && $0.assetID == assetID
        }.reduce(0) { total, input in
            total + (input.input as! SECP256K1TransferInput).amount
        }
    }
    
    public func getOutputTotal(assetID: AssetID) -> UInt64 {
        outputs.filter {
            type(of: $0.output) == SECP256K1TransferOutput.self
            && $0.assetID == assetID
        }.reduce(0) { total, output in
            total + (output.output as! SECP256K1TransferOutput).amount
        }
    }
    
    public func getBurn(assetID: AssetID) -> BigInt {
        let inputTotal = BigInt(getInputTotal(assetID: assetID))
        let outputTotal = BigInt(getOutputTotal(assetID: assetID))
        return inputTotal - outputTotal
    }
    
    public func checkGooseEgg(avax assetID: AssetID, outputTotal: UInt64? = nil) -> Bool {
        let outputTotal = outputTotal ?? getOutputTotal(assetID: assetID)
        let fee = getBurn(assetID: assetID)
        return fee <= 1_000_000_000 * 10 || fee <= outputTotal
    }
}
