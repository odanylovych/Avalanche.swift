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
    public let outputIndex: UInt32
    public let assetID: AssetID
    public let output: Output
    
    public init(transactionId: TransactionID, outputIndex: UInt32, assetID: AssetID, output: Output) {
        self.transactionId = transactionId
        self.outputIndex = outputIndex
        self.assetID = assetID
        self.output = output
    }
}

extension UTXO: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.codecID)
            .encode(transactionId)
            .encode(outputIndex)
            .encode(assetID)
            .encode(output)
    }
}
