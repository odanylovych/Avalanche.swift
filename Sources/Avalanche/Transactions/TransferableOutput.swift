//
//  TransferableOutput.swift
//  
//
//  Created by Ostap Danylovych on 26.08.2021.
//

import Foundation

public struct AssetID {
    public static let size = 32
    
    public let data: Data
    
    public init?(data: Data) {
        guard data.count == Self.size else {
            return nil
        }
        self.data = data
    }
}

extension AssetID: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(data, size: Self.size)
    }
}

public struct TransferableOutput {
    public let assetID: AssetID
    public let output: Output
    
    public init(assetId: AssetID, output: Output) {
        self.assetID = assetId
        self.output = output
    }
}

extension TransferableOutput: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(assetID).encode(output)
    }
}
