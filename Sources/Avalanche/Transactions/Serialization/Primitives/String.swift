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
            throw AvalancheEncoderError.invalidValue(self)
        }
        UInt16(count).encode(in: encoder)
        data.encode(in: encoder)
    }
}
