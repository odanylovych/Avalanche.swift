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

public protocol AvalancheEncoder {
    var output: Data { get }
    
    func encode(_ value: AvalancheEncodable) throws -> Self
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
    
    func write(_ data: Data) {
        output.append(data)
    }
}
