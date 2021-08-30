//
//  TransferableOutput.swift
//  
//
//  Created by Ostap Danylovych on 26.08.2021.
//

import Foundation

public struct AssetID: ID {
    public static var size = 32
    
    public var data: Data
    
    public init(_data: Data) {
        self.data = _data
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
