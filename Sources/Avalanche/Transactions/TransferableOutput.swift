//
//  TransferableOutput.swift
//  
//
//  Created by Ostap Danylovych on 26.08.2021.
//

import Foundation

public struct AssetId {
    public static let size = 32
    
    public let data: Data
    
    public init?(data: Data) {
        guard data.count == Self.size else {
            return nil
        }
        self.data = data
    }
}

extension AssetId: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(data, size: Self.size)
    }
}

public struct TransferableOutput {
    public let assetId: AssetId
    public let output: Output
    
    public init(assetId: AssetId, output: Output) {
        self.assetId = assetId
        self.output = output
    }
}

extension TransferableOutput: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(assetId).encode(output)
    }
}
