//
//  TransferableOutput.swift
//  
//
//  Created by Ostap Danylovych on 26.08.2021.
//

import Foundation

public struct TransferableOutput {
    public let assetId: Data
    public let output: Output
    
    public init(assetId: Data, output: Output) {
        self.assetId = assetId
        self.output = output
    }
}

extension TransferableOutput: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(assetId, size: 32).encode(output)
    }
}
