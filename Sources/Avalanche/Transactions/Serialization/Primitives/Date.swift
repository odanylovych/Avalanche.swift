//
//  Date.swift
//  
//
//  Created by Ostap Danylovych on 31.08.2021.
//

import Foundation

extension Date: AvalancheCodable {
    public init(from decoder: AvalancheDecoder) throws {
        self.init(timeIntervalSince1970: TimeInterval(try decoder.decode(UInt64.self)))
    }
    
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(UInt64(timeIntervalSince1970))
    }
}
