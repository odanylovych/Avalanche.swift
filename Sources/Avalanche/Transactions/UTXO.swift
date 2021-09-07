//
//  UTXO.swift
//  
//
//  Created by Ostap Danylovych on 31.08.2021.
//

import Foundation

public struct UTXO {
    public static let codecID: CodecID = .latest
    
    public let transactionId: TransactionID
    public let utxoIndex: UInt32
    public let assetID: AssetID
    public let output: Output
    
    public init(transactionId: TransactionID, outputIndex: UInt32, assetID: AssetID, output: Output) {
        self.transactionId = transactionId
        self.utxoIndex = outputIndex
        self.assetID = assetID
        self.output = output
    }
}

extension UTXO: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.codecID, name: "codecID")
            .encode(transactionId, name: "transactionId")
            .encode(utxoIndex, name: "utxoIndex")
            .encode(assetID, name: "assetID")
            .encode(output, name: "output")
    }
}
