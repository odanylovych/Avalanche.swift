//
//  Date.swift
//  
//
//  Created by Ostap Danylovych on 31.08.2021.
//

import Foundation

extension Date: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(UInt64(timeIntervalSince1970))
    }
}
