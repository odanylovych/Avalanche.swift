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
            throw AvalancheEncoderError.wrongFixedArraySize(
                self,
                actual: count,
                expected: size,
                AvalancheEncoderError.Context(path: encoder.path)
            )
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

extension Array: AvalancheFixedCodable, AvalancheCodable where Element: AvalancheCodable {
    public init(from decoder: AvalancheDecoder, size: Int) throws {
        self = try (0..<size).map { _ in try decoder.decode(Element.self) }
    }
    
    public init(from decoder: AvalancheDecoder) throws {
        let count: UInt32 = try decoder.decode()
        self = try (0..<count).map { _ in try decoder.decode(Element.self) }
    }
}

extension Data: AvalancheFixedCodable, AvalancheCodable {
    public init(from decoder: AvalancheDecoder, size: Int) throws {
        self = try decoder.read(count: size)
    }
    
    public init(from decoder: AvalancheDecoder) throws {
        let count: UInt32 = try decoder.decode()
        self = try decoder.read(count: Int(count))
    }
}
