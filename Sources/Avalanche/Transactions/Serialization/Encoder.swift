//
//  Encoder.swift
//  
//
//  Created by Ostap Danylovych on 25.08.2021.
//

import Foundation

public protocol AvalancheEncodable {
    func encode(in encoder: AvalancheEncoder) throws
}

public protocol AvalancheFixedEncodable {
    func encode(in encoder: AvalancheEncoder, size: Int) throws
}

public protocol AvalancheEncoder {
    var path: [String] { get }
    var output: Data { get }
    
    @discardableResult func encode(_ value: AvalancheEncodable) throws -> Self
    @discardableResult func encode(_ value: AvalancheEncodable, name: String) throws -> Self
    @discardableResult func encode(_ value: AvalancheFixedEncodable, size: Int) throws -> Self
    func write(_ data: Data)
}

class AEncoder: AvalancheEncoder {
    private(set) var output: Data
    private var context: AvalancheEncoderContext
    
    var path: [String] {
        return context.path
    }
    
    init() {
        output = Data()
        context = AvalancheEncoderContext()
    }
    
    func encode(_ value: AvalancheEncodable) throws -> Self {
        context.push(type(of: value))
        defer { context.pop() }
        try value.encode(in: self)
        return self
    }
    
    func encode(_ value: AvalancheEncodable, name: String) throws -> Self {
        context.push(type(of: value), name: name)
        defer { context.pop() }
        try value.encode(in: self)
        return self
    }
    
    func encode(_ value: AvalancheFixedEncodable, size: Int) throws -> Self {
        context.push(type(of: value), size: size)
        defer { context.pop() }
        try value.encode(in: self, size: size)
        return self
    }
    
    func write(_ data: Data) {
        output.append(data)
    }
}
