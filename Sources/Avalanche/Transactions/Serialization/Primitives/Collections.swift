//
//  Collections.swift
//  
//
//  Created by Ostap Danylovych on 26.08.2021.
//

import Foundation

// Fixed-Length Array

extension Collection where Element: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder, size: Int) throws {
        guard count == size else {
            throw AvalancheEncoderError.wrongFixedArraySize(self, actual: count, expected: size)
        }
        try forEach { try encoder.encode($0) }
    }
}

// Variable-Length Array

extension Collection where Element: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(UInt32(count))
        try forEach { try encoder.encode($0) }
    }
}

extension Array: AvalancheFixedEncodable, AvalancheEncodable where Element: AvalancheEncodable {}
extension Data: AvalancheFixedEncodable, AvalancheEncodable {}
