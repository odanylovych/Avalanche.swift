//
//  String.swift
//  
//
//  Created by Ostap Danylovych on 26.08.2021.
//

import Foundation

extension String: AvalancheCodable {
    public init(from decoder: AvalancheDecoder) throws {
        let count = try UInt16(from: decoder)
        let data = try Data(from: decoder, size: Int(count))
        guard let string = String(data: data, encoding: .utf8) else {
            throw AvalancheDecoderError.dataCorrupted(data, description: "Bad UTF8 string data")
        }
        self = string
    }
    
    public func encode(in encoder: AvalancheEncoder) throws {
        guard let data = data(using: .utf8) else {
            throw AvalancheEncoderError.invalidValue(
                self,
                AvalancheEncoderError.Context(
                    path: encoder.path,
                    description: "Can't be encoded to UTF8"
                )
            )
        }
        try encoder.encode(UInt16(data.count)).encode(data, size: data.count)
    }
}
