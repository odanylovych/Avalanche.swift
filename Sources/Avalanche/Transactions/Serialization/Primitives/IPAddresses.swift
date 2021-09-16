//
//  IPAddresses.swift
//  
//
//  Created by Ostap Danylovych on 26.08.2021.
//

import Foundation

public struct IPv4Address: Equatable {
    public let host: (UInt8, UInt8, UInt8, UInt8)
    public let port: UInt16
    
    public init(host: (UInt8, UInt8, UInt8, UInt8), port: UInt16) {
        self.host = host
        self.port = port
    }
    
    public static func == (lhs: IPv4Address, rhs: IPv4Address) -> Bool {
        lhs.host == rhs.host && lhs.port == rhs.port
    }
}

extension IPv4Address: AvalancheCodable {
    public init(from decoder: AvalancheDecoder) throws {
        let _ = try Data(from: decoder, size: 12)
        self.init(
            host: (
                try UInt8(from: decoder),
                try UInt8(from: decoder),
                try UInt8(from: decoder),
                try UInt8(from: decoder)
            ),
            port: try UInt16(from: decoder)
        )
    }
    
    public func encode(in encoder: AvalancheEncoder) throws {
        encoder.write(Data(count: 12))
        try encoder.encode(host.0)
            .encode(host.1)
            .encode(host.2)
            .encode(host.3)
            .encode(port)
    }
}

public struct IPv6Address: Equatable {
    public let host: [UInt16]
    public let port: UInt16
    
    public init(host: [UInt16], port: UInt16) {
        self.host = host
        self.port = port
    }
}

extension IPv6Address: AvalancheCodable {
    public init(from decoder: AvalancheDecoder) throws {
        self.init(
            host: try [UInt16](from: decoder, size: 8),
            port: try UInt16(from: decoder)
        )
    }
    
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(host, size: 8).encode(port)
    }
}
