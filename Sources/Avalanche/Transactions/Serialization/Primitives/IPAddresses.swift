//
//  IPAddresses.swift
//  
//
//  Created by Ostap Danylovych on 26.08.2021.
//

import Foundation

public struct IPv4Address {
    public let host: (UInt8, UInt8, UInt8, UInt8)
    public let port: UInt16
    
    public init(host: (UInt8, UInt8, UInt8, UInt8), port: UInt16) {
        self.host = host
        self.port = port
    }
}

extension IPv4Address: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) throws {
        encoder.write(Data(count: 12))
        try encoder.encode(host.0)
            .encode(host.1)
            .encode(host.2)
            .encode(host.3)
            .encode(port)
    }
}

public struct IPv6Address {
    public let host: [UInt16]
    public let port: UInt16
    
    public init(host: [UInt16], port: UInt16) {
        self.host = host
        self.port = port
    }
}

extension IPv6Address: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(host, size: 8).encode(port)
    }
}
