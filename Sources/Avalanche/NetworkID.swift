//
//  NetworkID.swift
//  
//
//  Created by Yehor Popovych on 10/14/20.
//

import Foundation

public struct NetworkID: Equatable, Hashable {
    public let value: UInt32
    public let hrp: String
    
    private static let hrps: [UInt32: String] = [
        0: "custom",
        1: "avax",
        2: "cascade",
        3: "denali",
        4: "everest",
        5: "fuji",
        12345: "local",
    ]
    
    public init(_ value: UInt32, _ hrp: String? = nil) {
        self.value = value
        self.hrp = hrp ?? Self.hrps[value] ?? "custom"
    }
    
    public static let manhattan = Self(0)
    public static let avalanche = Self(1)
    public static let cascade = Self(2)
    public static let denali = Self(3)
    public static let everest = Self(4)
    public static let fuji = Self(5)
    
    public static let main = Self.avalanche
    public static let test = Self.fuji
    public static let local = Self(12345)
}

extension NetworkID: AvalancheCodable {
    public init(from decoder: AvalancheDecoder) throws {
        self.init(try decoder.decode())
    }
    
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(value)
    }
}
