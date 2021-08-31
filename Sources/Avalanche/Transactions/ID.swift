//
//  ID.swift
//  
//
//  Created by Ostap Danylovych on 30.08.2021.
//

import Foundation
import Base58

public protocol ID: AvalancheEncodable {
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
        guard let data = Base58.base58CheckDecode(cb58) else {
            return nil
        }
        self.init(data: Data(data))
    }
    
    public func hex() -> String {
        raw.hex()
    }
    
    public func cb58() -> String {
        Base58.base58CheckEncode(Array(raw))
    }
}

extension ID {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(raw, size: Self.size)
    }
}
