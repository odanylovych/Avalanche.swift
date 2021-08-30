//
//  ID.swift
//  
//
//  Created by Ostap Danylovych on 30.08.2021.
//

import Foundation

public protocol ID: AvalancheEncodable {
    static var size: Int { get }

    var data: Data { get }
    
    init(_data: Data)
}

extension ID {
    public init?(data: Data) {
        guard data.count == Self.size else {
            return nil
        }
        self.init(_data: data)
    }
    
    public init?(hex: String) {
        guard let data = Data(hex: hex) else {
            return nil
        }
        self.init(data: data)
    }
    
    public init?(cb58: String) {
        fatalError("Not implemented")
    }
}

extension ID {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(data, size: Self.size)
    }
}
