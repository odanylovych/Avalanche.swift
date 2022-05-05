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

class DefaultAvalancheEncoder: AvalancheEncoder {
    private(set) var output: Data
    private var encoderPath: AvalancheCoderPath
    
    var path: [String] {
        return encoderPath.path
    }
    
    init() {
        output = Data()
        encoderPath = AvalancheCoderPath()
    }
    
    func encode(_ value: AvalancheEncodable) throws -> Self {
        encoderPath.push(type(of: value))
        defer { encoderPath.pop() }
        try value.encode(in: self)
        return self
    }
    
    func encode(_ value: AvalancheEncodable, name: String) throws -> Self {
        encoderPath.push(type(of: value), name: name)
        defer { encoderPath.pop() }
        try value.encode(in: self)
        return self
    }
    
    func encode(_ value: AvalancheFixedEncodable, size: Int) throws -> Self {
        encoderPath.push(type(of: value), size: size)
        defer { encoderPath.pop() }
        try value.encode(in: self, size: size)
        return self
    }
    
    func write(_ data: Data) {
        output.append(data)
    }
}
