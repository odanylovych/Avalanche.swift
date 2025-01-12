//
//  ID.swift
//  
//
//  Created by Ostap Danylovych on 30.08.2021.
//

import Foundation

public protocol ID: AvalancheCodable, Hashable {
    static var size: Int { get }

    var raw: Data { get }
    
    init(raw: Data)
}

extension ID {
    public init?(data: Data) {
        guard data.count == Self.size else {
            return nil
        }
        self.init(raw: data)
    }
    
    public init?(hex: String) {
        guard let data = Data(hex: hex) else {
            return nil
        }
        self.init(data: data)
    }
    
    public init?(cb58: String) {
        guard let data = Algos.Base58.from(cb58: cb58) else {
            return nil
        }
        self.init(data: Data(data))
    }
    
    public func hex() -> String {
        raw.hex()
    }
    
    public func cb58() -> String {
        Algos.Base58.cb58(data: raw)
    }
}

extension ID {
    public init(from decoder: AvalancheDecoder) throws {
        let data: Data = try decoder.decode(size: Self.size)
        guard let id = Self(data: data) else {
            throw AvalancheDecoderError.dataCorrupted(
                data,
                AvalancheDecoderError.Context(path: decoder.path, description: "Bad ID data")
            )
        }
        self = id
    }
    
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(raw, size: Self.size)
    }
}
