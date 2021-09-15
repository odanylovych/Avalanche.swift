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

extension Array: AvalancheFixedDecodable where Element: AvalancheDecodable {
    public init(from decoder: AvalancheDecoder, size: Int) throws {
        self = try (0..<size).map { _ in try decoder.decode(Element.self) }
    }
}

extension Array: AvalancheDecodable where Element: AvalancheDecodable {
    public init(from decoder: AvalancheDecoder) throws {
        let count = try UInt32(from: decoder)
        self = try (0..<count).map { _ in try decoder.decode(Element.self) }
    }
}

extension Array: AvalancheFixedEncodable, AvalancheEncodable where Element: AvalancheEncodable {}

extension Data: AvalancheFixedDecodable {
    public init(from decoder: AvalancheDecoder, size: Int) throws {
        self = try decoder.read(count: size)
    }
}

extension Data: AvalancheDecodable {
    public init(from decoder: AvalancheDecoder) throws {
        let count = try UInt32(from: decoder)
        self = try decoder.read(count: Int(count))
    }
}

extension Data: AvalancheFixedEncodable, AvalancheEncodable {}
