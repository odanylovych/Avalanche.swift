//
//  Avalanche.swift
//  
//
//  Created by Daniel Leping on 09/01/2021.
//

import Foundation

extension Data {
    public var bytes: Array<UInt8> {
        return Array(self)
    }
}

public enum Avalanche {
    public static func sign(data: Data, with key: Data) -> Data? {
        SECP256K1.sign(data: data.bytes, with: key)
    }
}
