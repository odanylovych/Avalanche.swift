//
//  Integers.swift
//  
//
//  Created by Ostap Danylovych on 26.08.2021.
//

import Foundation

extension UInt8: AvalancheCodable {
    public init(from decoder: AvalancheDecoder) throws {
        let data = try decoder.read(count: 1)
        self = data.withUnsafeBytes { $0.load(as: Self.self).bigEndian }
    }
    
    public func encode(in encoder: AvalancheEncoder) {
        encoder.write(Data(repeating: self, count: 1))
    }
}

extension Int8: AvalancheCodable {
    public init(from decoder: AvalancheDecoder) throws {
        let data = try decoder.read(count: 1)
        self = data.withUnsafeBytes { $0.load(as: Self.self).bigEndian }
    }
    
    public func encode(in encoder: AvalancheEncoder) {
        encoder.write(Data(repeating: UInt8(bitPattern: self), count: 1))
    }
}

extension UInt16: AvalancheCodable {
    public init(from decoder: AvalancheDecoder) throws {
        let data = try decoder.read(count: 2)
        self = data.withUnsafeBytes { $0.load(as: Self.self).bigEndian }
    }
    
    public func encode(in encoder: AvalancheEncoder) {
        encoder.write(withUnsafeBytes(of: self.bigEndian) { Data($0) })
    }
}

extension Int16: AvalancheCodable {
    public init(from decoder: AvalancheDecoder) throws {
        let data = try decoder.read(count: 2)
        self = data.withUnsafeBytes { $0.load(as: Self.self).bigEndian }
    }
    
    public func encode(in encoder: AvalancheEncoder) {
        encoder.write(withUnsafeBytes(of: self.bigEndian) { Data($0) })
    }
}

extension UInt32: AvalancheCodable {
    public init(from decoder: AvalancheDecoder) throws {
        let data = try decoder.read(count: 4)
        self = data.withUnsafeBytes { $0.load(as: Self.self).bigEndian }
    }
    
    public func encode(in encoder: AvalancheEncoder) {
        encoder.write(withUnsafeBytes(of: self.bigEndian) { Data($0) })
    }
}

extension Int32: AvalancheCodable {
    public init(from decoder: AvalancheDecoder) throws {
        let data = try decoder.read(count: 4)
        self = data.withUnsafeBytes { $0.load(as: Self.self).bigEndian }
    }
    
    public func encode(in encoder: AvalancheEncoder) {
        encoder.write(withUnsafeBytes(of: self.bigEndian) { Data($0) })
    }
}

extension UInt64: AvalancheCodable {
    public init(from decoder: AvalancheDecoder) throws {
        let data = try decoder.read(count: 8)
        self = data.withUnsafeBytes { $0.load(as: Self.self).bigEndian }
    }
    
    public func encode(in encoder: AvalancheEncoder) {
        encoder.write(withUnsafeBytes(of: self.bigEndian) { Data($0) })
    }
}

extension Int64: AvalancheCodable {
    public init(from decoder: AvalancheDecoder) throws {
        let data = try decoder.read(count: 8)
        self = data.withUnsafeBytes { $0.load(as: Self.self).bigEndian }
    }
    
    public func encode(in encoder: AvalancheEncoder) {
        encoder.write(withUnsafeBytes(of: self.bigEndian) { Data($0) })
    }
}
