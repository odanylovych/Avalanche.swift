//
//  TransferableOp.swift
//  
//
//  Created by Ostap Danylovych on 28.08.2021.
//

import Foundation

public struct UTXOID {
    public let txID: TxID
    public let utxoIndex: UInt32
    
    public init(txID: TxID, utxoIndex: UInt32) {
        self.txID = txID
        self.utxoIndex = utxoIndex
    }
}

extension UTXOID: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(txID).encode(utxoIndex)
    }
}

public struct TransferableOp {
    public let assetID: AssetID
    public let utxoIDs: [UTXOID]
    public let transferOp: Operation
    
    public init(assetID: AssetID, utxoIDs: [UTXOID], transferOp: Operation) {
        self.assetID = assetID
        self.utxoIDs = utxoIDs
        self.transferOp = transferOp
    }
}

extension TransferableOp: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(assetID)
            .encode(utxoIDs)
            .encode(transferOp)
    }
}
