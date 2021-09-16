//
//  TransferableOutput.swift
//  
//
//  Created by Ostap Danylovych on 26.08.2021.
//

import Foundation

public struct AssetID: ID {
    public static let size = 32
    
    public let raw: Data
    
    public init(raw: Data) {
        self.raw = raw
    }
}

public struct TransferableOutput {
    public let assetID: AssetID
    public let output: Output
    
    public init(assetID: AssetID, output: Output) {
        self.assetID = assetID
        self.output = output
    }
}

extension TransferableOutput: AvalancheCodable {
    public init(from decoder: AvalancheDecoder) throws {
        self.init(
            assetID: try AssetID(from: decoder),
            output: try Output.from(decoder: decoder)
        )
    }
    
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(assetID, name: "assetID")
            .encode(output, name: "output")
    }
}
