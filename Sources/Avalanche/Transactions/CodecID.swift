//
//  CodecID.swift
//  
//
//  Created by Ostap Danylovych on 26.08.2021.
//

import Foundation

public enum CodecID: UInt16 {
    case latest = 0
}

extension CodecID: AvalancheCodable {
    public init(from decoder: AvalancheDecoder) throws {
        let rawValue: UInt16 = try decoder.decode()
        guard let codecID = Self(rawValue: rawValue) else {
            throw AvalancheDecoderError.dataCorrupted(
                rawValue,
                AvalancheDecoderError.Context(path: decoder.path, description: "Cannot find such CodecID")
            )
        }
        self = codecID
    }
    
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(rawValue)
    }
}
