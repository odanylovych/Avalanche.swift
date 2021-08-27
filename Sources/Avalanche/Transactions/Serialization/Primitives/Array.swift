//
//  Array.swift
//  
//
//  Created by Ostap Danylovych on 26.08.2021.
//

import Foundation

// Fixed-Length Array

public protocol FixedArray: AvalancheEncodable {
    associatedtype E: AvalancheEncodable
    
    static var count: UInt32 { get }
    
    var array: [E] { get }
    
    init?(array: [E])
}

extension FixedArray {
    public func encode(in encoder: AvalancheEncoder) throws {
        try array.forEach { try $0.encode(in: encoder) }
    }
}

// Variable-Length Array

extension Array: AvalancheEncodable where Element: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) throws {
        UInt32(count).encode(in: encoder)
        try forEach { try $0.encode(in: encoder) }
    }
}
