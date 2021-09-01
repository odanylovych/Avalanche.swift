//
//  TransferableOperation.swift
//  
//
//  Created by Ostap Danylovych on 28.08.2021.
//

import Foundation

public struct UTXOID {
    public let transactionID: TransactionID
    public let utxoIndex: UInt32
    
    public init(transactionID: TransactionID, utxoIndex: UInt32) {
        self.transactionID = transactionID
        self.utxoIndex = utxoIndex
    }
}

extension UTXOID: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(transactionID).encode(utxoIndex)
    }
}

public struct TransferableOperation {
    public let assetID: AssetID
    public let utxoIDs: [UTXOID]
    public let transferOperation: Operation
    
    public init(assetID: AssetID, utxoIDs: [UTXOID], transferOperation: Operation) {
        self.assetID = assetID
        self.utxoIDs = utxoIDs
        self.transferOperation = transferOperation
    }
}

extension TransferableOperation: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(assetID)
            .encode(utxoIDs)
            .encode(transferOperation)
    }
}
