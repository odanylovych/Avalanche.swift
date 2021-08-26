//
//  Integers.swift
//  
//
//  Created by Ostap Danylovych on 26.08.2021.
//

import Foundation

extension UInt8: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) {
        encoder.write(Data(repeating: self, count: 1))
    }
}

extension Int8: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) {
        encoder.write(Data(repeating: UInt8(bitPattern: self), count: 1))
    }
}

extension UInt16: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) {
        encoder.write(withUnsafeBytes(of: self.bigEndian) { Data($0) })
    }
}

extension Int16: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) {
        encoder.write(withUnsafeBytes(of: self.bigEndian) { Data($0) })
    }
}

extension UInt32: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) {
        encoder.write(withUnsafeBytes(of: self.bigEndian) { Data($0) })
    }
}

extension Int32: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) {
        encoder.write(withUnsafeBytes(of: self.bigEndian) { Data($0) })
    }
}

extension UInt64: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) {
        encoder.write(withUnsafeBytes(of: self.bigEndian) { Data($0) })
    }
}

extension Int64: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) {
        encoder.write(withUnsafeBytes(of: self.bigEndian) { Data($0) })
    }
}
