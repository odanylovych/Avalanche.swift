//
//  UTXO.swift
//  
//
//  Created by Ostap Danylovych on 31.08.2021.
//

import Foundation

public struct UTXO {
    public static let codecID: CodecID = .latest
    
    public let transactionID: TransactionID
    public let utxoIndex: UInt32
    public let assetID: AssetID
    public let output: Output
    
    public init(transactionId: TransactionID, outputIndex: UInt32, assetID: AssetID, output: Output) {
        self.transactionID = transactionId
        self.utxoIndex = outputIndex
        self.assetID = assetID
        self.output = output
    }
}

extension UTXO: AvalancheCodable {
    public init(from decoder: AvalancheDecoder) throws {
        transactionID = try TransactionID(from: decoder)
        utxoIndex = try UInt32(from: decoder)
        assetID = try AssetID(from: decoder)
        output = try Output.from(decoder: decoder)
    }
    
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.codecID, name: "codecID")
            .encode(transactionID, name: "transactionID")
            .encode(utxoIndex, name: "utxoIndex")
            .encode(assetID, name: "assetID")
            .encode(output, name: "output")
    }
}
