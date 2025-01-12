//
//  TransferableInput.swift
//  
//
//  Created by Ostap Danylovych on 27.08.2021.
//

import Foundation

public struct TransactionID: ID {
    public static let size = 32
    
    public let raw: Data
    
    public init(raw: Data) {
        self.raw = raw
    }
}

public struct TransferableInput: Equatable {
    public let transactionID: TransactionID
    public let utxoIndex: UInt32
    public let assetID: AssetID
    public let input: Input
    
    public init(transactionID: TransactionID, utxoIndex: UInt32, assetID: AssetID, input: Input) {
        self.transactionID = transactionID
        self.utxoIndex = utxoIndex
        self.assetID = assetID
        self.input = input
    }
}

extension TransferableInput: AvalancheCodable {
    public init(from decoder: AvalancheDecoder) throws {
        self.init(
            transactionID: try decoder.decode(name: "transactionID"),
            utxoIndex: try decoder.decode(name: "utxoIndex"),
            assetID: try decoder.decode(name: "assetID"),
            input: try decoder.dynamic(name: "input")
        )
    }
    
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(transactionID, name: "transactionID")
            .encode(utxoIndex, name: "utxoIndex")
            .encode(assetID, name: "assetID")
            .encode(input, name: "input")
    }
}

extension TransferableInput: Comparable {
    public static func < (lhs: TransferableInput, rhs: TransferableInput) -> Bool {
        let encoder = { DefaultAvalancheEncoder() }
        return try! encoder().encode(lhs).output
            .lexicographicallyPrecedes(encoder().encode(rhs).output)
    }
}
