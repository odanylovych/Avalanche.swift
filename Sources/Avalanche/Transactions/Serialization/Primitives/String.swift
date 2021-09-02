//
//  String.swift
//  
//
//  Created by Ostap Danylovych on 26.08.2021.
//

import Foundation

extension String: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) throws {
        guard let data = data(using: .utf8) else {
            throw AvalancheEncoderError.invalidValue(
                self,
                AvalancheEncoderError.Context(
                    path: encoder.path,
                    description: "Can't be encoded to UTF8: \(self)"
                )
            )
        }
        try encoder.encode(UInt16(data.count)).encode(data, size: data.count)
    }
}
