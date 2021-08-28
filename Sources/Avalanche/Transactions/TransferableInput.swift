//
//  TransferableInput.swift
//  
//
//  Created by Ostap Danylovych on 27.08.2021.
//

import Foundation

public struct TransactionID {
    public static let size = 32

    public let data: Data

    public init?(data: Data) {
        guard data.count == Self.size else {
            return nil
        }
        self.data = data
    }
}

extension TransactionID: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(data, size: Self.size)
    }
}

public struct TransferableInput {
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

extension TransferableInput: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(transactionID)
            .encode(utxoIndex)
            .encode(assetID)
            .encode(input)
    }
}
