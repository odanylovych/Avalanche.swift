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

public protocol AvalancheDecoder {
    init(data: Data)
    
    func decode<T: AvalancheDecodable>() throws -> T
    func read(count: Int) throws -> Data
}

extension AvalancheDecoder {
    public func decode<T: AvalancheDecodable>(_ type: T.Type) throws -> T {
        return try self.decode()
    }
}

class ADecoder: AvalancheDecoder {
    private let data: Data
    private var position: Int
    
    required init(data: Data) {
        self.data = data
        position = 0
    }
    
    func decode<T: AvalancheDecodable>() throws -> T {
        return try T(from: self)
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
