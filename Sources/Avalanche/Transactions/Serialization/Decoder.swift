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

public struct DefaultAvalancheDecoderContext: AvalancheDecoderContext {
    public let hrp: String
    public let chainId: String
    public let dynamicParser: DynamicTypeParser
}

public protocol AvalancheDecoder {
    var path: [String] { get }
    var context: AvalancheDecoderContext { get }
    
    init(context: AvalancheDecoderContext, data: Data)
    
    func decode<T: AvalancheDecodable>() throws -> T
    func decode<T: AvalancheDecodable>(name: String) throws -> T
    func decode<T: AvalancheFixedDecodable>(size: Int) throws -> T
    func dynamic<T: AvalancheDynamicDecodable>() throws -> T
    func dynamic<T: AvalancheDynamicDecodable>(name: String) throws -> T
    func read(count: Int) throws -> Data
}

extension AvalancheDecoder {
    public func decode<T: AvalancheDecodable>(_ type: T.Type) throws -> T {
        return try self.decode()
    }
    
    public func decode<T: AvalancheDecodable>(_ type: T.Type, name: String) throws -> T {
        return try self.decode(name: name)
    }
    
    public func decode<T: AvalancheFixedDecodable>(_ type: T.Type, size: Int) throws -> T {
        return try self.decode(size: size)
    }
    
    public func decode<T: AvalancheDynamicDecodable>(dynamic: T.Type) throws -> T {
        return try self.dynamic()
    }
    
    public func decode<T: AvalancheDynamicDecodable>(dynamic: T.Type, name: String) throws -> T {
        return try self.dynamic(name: name)
    }
}

class ADecoder: AvalancheDecoder {
    var context: AvalancheDecoderContext
    private let data: Data
    private var position: Int
    private var decoderPath: AvalancheCoderPath
    
    var path: [String] {
        return decoderPath.path
    }
    
    required init(context: AvalancheDecoderContext, data: Data) {
        self.context = context
        self.data = data
        position = 0
        decoderPath = AvalancheCoderPath()
    }
    
    func decode<T: AvalancheDecodable>() throws -> T {
        decoderPath.push(T.self)
        defer { decoderPath.pop() }
        return try T(from: self)
    }
    
    public func decode<T: AvalancheDecodable>(name: String) throws -> T {
        decoderPath.push(T.self, name: name)
        defer { decoderPath.pop() }
        return try T(from: self)
    }
    
    func decode<T: AvalancheFixedDecodable>(size: Int) throws -> T {
        decoderPath.push(T.self, size: size)
        defer { decoderPath.pop() }
        return try T(from: self, size: size)
    }
    
    func dynamic<T: AvalancheDynamicDecodable>() throws -> T {
        decoderPath.push(T.self)
        defer { decoderPath.pop() }
        return try T.from(decoder: self)
    }
    
    func dynamic<T: AvalancheDynamicDecodable>(name: String) throws -> T {
        decoderPath.push(T.self, name: name)
        defer { decoderPath.pop() }
        return try T.from(decoder: self)
    }
    
    func read(count: Int) throws -> Data {
        guard count <= data.count - position else {
            throw AvalancheDecoderError.noDataLeft(AvalancheDecoderError.Context(path: path))
        }
        let data = data.subdata(in: position..<position+count)
        position += count
        return data
    }
}
