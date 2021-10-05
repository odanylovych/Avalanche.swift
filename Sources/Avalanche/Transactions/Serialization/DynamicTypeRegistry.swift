//
//  DynamicTypeRegistry.swift
//  
//
//  Created by Ostap Danylovych on 17.09.2021.
//

import Foundation

public protocol AvalancheDynamicDecodableTypeID: AvalancheDynamicDecodable {
    init(dynamic decoder: AvalancheDecoder, typeID: UInt32) throws
}

extension AvalancheDynamicDecodableTypeID where Self: AvalancheDecodable {
    public init(from decoder: AvalancheDecoder) throws {
        try self.init(dynamic: decoder, typeID: try decoder.decode())
    }
}

public protocol DynamicTypeRegistry: DynamicTypeParser {
    associatedtype TID: TypeID & Hashable & RawRepresentable
    
    static var instance: Self { get }
    
    var inputs: [TID: (AvalancheDecoder, TID.RawValue) throws -> Input] { get }
    var outputs: [TID: (AvalancheDecoder, TID.RawValue) throws -> Output] { get }
    var operations: [TID: (AvalancheDecoder, TID.RawValue) throws -> Operation] { get }
    var credentials: [TID: (AvalancheDecoder, TID.RawValue) throws -> Credential] { get }
    var transactions: [TID: (AvalancheDecoder, TID.RawValue) throws -> UnsignedAvalancheTransaction] { get }
}

extension DynamicTypeRegistry {
    public func decode(input decoder: AvalancheDecoder) throws -> Input {
        let type: TID = try decoder.decode()
        guard let initializer = inputs[type] else {
            throw AvalancheDecoderError.dataCorrupted(
                type,
                AvalancheDecoderError.Context(path: decoder.path, description: "Wrong Input type")
            )
        }
        return try initializer(decoder, type.rawValue)
    }
    
    public func decode(output decoder: AvalancheDecoder) throws -> Output {
        let type: TID = try decoder.decode()
        guard let initializer = outputs[type] else {
            throw AvalancheDecoderError.dataCorrupted(
                type,
                AvalancheDecoderError.Context(path: decoder.path, description: "Wrong Output type")
            )
        }
        return try initializer(decoder, type.rawValue)
    }

    public func decode(operation decoder: AvalancheDecoder) throws -> Operation {
        let type: TID = try decoder.decode()
        guard let initializer = operations[type] else {
            throw AvalancheDecoderError.dataCorrupted(
                type,
                AvalancheDecoderError.Context(path: decoder.path, description: "Wrong Operation type")
            )
        }
        return try initializer(decoder, type.rawValue)
    }

    public func decode(credential decoder: AvalancheDecoder) throws -> Credential {
        let type: TID = try decoder.decode()
        guard let initializer = credentials[type] else {
            throw AvalancheDecoderError.dataCorrupted(
                type,
                AvalancheDecoderError.Context(path: decoder.path, description: "Wrong Credential type")
            )
        }
        return try initializer(decoder, type.rawValue)
    }

    public func decode(transaction decoder: AvalancheDecoder) throws -> UnsignedAvalancheTransaction {
        let type: TID = try decoder.decode()
        guard let initializer = transactions[type] else {
            throw AvalancheDecoderError.dataCorrupted(
                type,
                AvalancheDecoderError.Context(path: decoder.path, description: "Wrong Transaction type")
            )
        }
        return try initializer(decoder, type.rawValue)
    }
    
    public static func wrap<I: Input>(_ input: I.Type) -> (AvalancheDecoder, UInt32) throws -> Input {
        { decoder, id in try I(dynamic: decoder, typeID: id) }
    }
    
    public static func wrap<O: Output>(_ output: O.Type) -> (AvalancheDecoder, UInt32) throws -> Output {
        { decoder, id in try O(dynamic: decoder, typeID: id) }
    }

    public static func wrap<O: Operation>(_ operation: O.Type) -> (AvalancheDecoder, UInt32) throws -> Operation {
        { decoder, id in try O(dynamic: decoder, typeID: id) }
    }

    public static func wrap<C: Credential>(_ credential: C.Type) -> (AvalancheDecoder, UInt32) throws -> Credential {
        { decoder, id in try C(dynamic: decoder, typeID: id) }
    }

    public static func wrap<T: UnsignedAvalancheTransaction>(_ transaction: T.Type) -> (AvalancheDecoder, UInt32) throws -> UnsignedAvalancheTransaction {
        { decoder, id in try T(dynamic: decoder, typeID: id) }
    }
}
