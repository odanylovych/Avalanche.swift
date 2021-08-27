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
    private static let _encoder_prefix = Data(count: 12)
    
    public func encode(in encoder: AvalancheEncoder) {
        encoder.write(Self._encoder_prefix)
        host.0.encode(in: encoder)
        host.1.encode(in: encoder)
        host.2.encode(in: encoder)
        host.3.encode(in: encoder)
        port.encode(in: encoder)
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
                data.encode(in: encoder)
            } else {
                encoder.write(Data(count: 2))
            }
        }
        port.encode(in: encoder)
    }
}
