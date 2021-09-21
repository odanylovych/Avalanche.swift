//
//  Decoder.swift
//  
//
//  Created by Ostap Danylovych on 15.09.2021.
//

import Foundation

public protocol AvalancheDecodable {
    init(from decoder: AvalancheDecoder) throws
}

public protocol AvalancheFixedDecodable {
    init(from decoder: AvalancheDecoder, size: Int) throws
}

public protocol AvalancheDynamicDecodable {
    static func from(decoder: AvalancheDecoder) throws -> Self
}

public protocol AvalancheDecoderContext {
    var hrp: String { get }
    var chainId: String { get }
    var dynamicParser: DynamicTypeParser { get }
}

public protocol AvalancheDecoder {
    var context: AvalancheDecoderContext { get }
    
    init(context: AvalancheDecoderContext, data: Data)
    
    func decode<T: AvalancheDecodable>() throws -> T
    func decode<T: AvalancheFixedDecodable>(size: Int) throws -> T
    func dynamic<T: AvalancheDynamicDecodable>() throws -> T
    func read(count: Int) throws -> Data
}

extension AvalancheDecoder {
    public func decode<T: AvalancheDecodable>(_ type: T.Type) throws -> T {
        return try self.decode()
    }
    
    public func decode<T: AvalancheFixedDecodable>(_ type: T.Type, size: Int) throws -> T {
        return try self.decode(size: size)
    }
    
    public func decode<T: AvalancheDynamicDecodable>(dynamic: T.Type) throws -> T {
        return try self.dynamic()
    }
}

class ADecoder: AvalancheDecoder {
    var context: AvalancheDecoderContext
    private let data: Data
    private var position: Int
    
    required init(context: AvalancheDecoderContext, data: Data) {
        self.context = context
        self.data = data
        position = 0
    }
    
    func decode<T: AvalancheDecodable>() throws -> T {
        return try T(from: self)
    }
    
    func decode<T: AvalancheFixedDecodable>(size: Int) throws -> T {
        return try T(from: self, size: size)
    }
    
    func dynamic<T: AvalancheDynamicDecodable>() throws -> T {
        return try T.from(decoder: self)
    }
    
    func read(count: Int) throws -> Data {
        guard count <= data.count - position else {
            throw AvalancheDecoderError.noDataLeft
        }
        let data = data.subdata(in: position..<position+count)
        position += count
        return data
    }
}
