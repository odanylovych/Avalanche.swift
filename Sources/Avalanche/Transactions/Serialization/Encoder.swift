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
    var output: Data { get }
    
    @discardableResult func encode(_ value: AvalancheEncodable) throws -> Self
    @discardableResult func encode(_ value: AvalancheFixedEncodable, size: Int) throws -> Self
    func write(_ data: Data)
}

class AEncoder: AvalancheEncoder {
    public private(set) var output: Data
    
    init() {
        output = Data()
    }
    
    func encode(_ value: AvalancheEncodable) throws -> Self {
        try value.encode(in: self)
        return self
    }
    
    func encode(_ value: AvalancheFixedEncodable, size: Int) throws -> Self {
        try value.encode(in: self, size: size)
        return self
    }
    
    func write(_ data: Data) {
        output.append(data)
    }
}
