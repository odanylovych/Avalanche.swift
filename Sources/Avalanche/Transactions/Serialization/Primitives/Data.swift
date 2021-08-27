//
//  Data.swift
//  
//
//  Created by Ostap Danylovych on 26.08.2021.
//

import Foundation

extension Data: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) {
        encoder.write(self)
    }
}
