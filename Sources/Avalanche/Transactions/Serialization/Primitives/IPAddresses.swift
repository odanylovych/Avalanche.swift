//
//  IPAddresses.swift
//  
//
//  Created by Ostap Danylovych on 26.08.2021.
//

import Foundation

public struct IPv4Address {
    public private(set) var host: (UInt8, UInt8, UInt8, UInt8)
    public private(set) var port: UInt16
    
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
    public private(set) var host: [String]
    public private(set) var port: UInt16
    
    public init(host: [String], port: UInt16) {
        self.host = host
        self.port = port
    }
}

extension IPv6Address: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) throws {
        for i in 0...7 {
            if i < host.count {
                guard let data = Data(hex: host[i]) else {
                    throw AvalancheEncoderError.invalidValue(host[i])
                }
                try encoder.encode(data, data.count)
            } else {
                encoder.write(Data(count: 2))
            }
        }
        try encoder.encode(port)
    }
}
