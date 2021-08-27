//
//  CodecID.swift
//  
//
//  Created by Ostap Danylovych on 26.08.2021.
//

import Foundation

public enum CodecID: UInt16 {
    case latest = 0
}

extension CodecID: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(rawValue)
    }
}
