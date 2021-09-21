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
    
    public init(transactionID: TransactionID, utxoIndex: UInt32, assetID: AssetID, output: Output) {
        self.transactionID = transactionID
        self.utxoIndex = utxoIndex
        self.assetID = assetID
        self.output = output
    }
}

extension UTXO: AvalancheCodable {
    public init(from decoder: AvalancheDecoder) throws {
        self.init(
            transactionID: try decoder.decode(),
            utxoIndex: try decoder.decode(),
            assetID: try decoder.decode(),
            output: try decoder.dynamic()
        )
    }
    
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.codecID, name: "codecID")
            .encode(transactionID, name: "transactionID")
            .encode(utxoIndex, name: "utxoIndex")
            .encode(assetID, name: "assetID")
            .encode(output, name: "output")
    }
}
