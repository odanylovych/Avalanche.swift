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
        let rawValue = try UInt16(from: decoder)
        guard let codecID = Self(rawValue: rawValue) else {
            throw AvalancheDecoderError.dataCorrupted(rawValue, description: "Wrong CodecID")
        }
        self = codecID
    }
    
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(rawValue)
    }
}
