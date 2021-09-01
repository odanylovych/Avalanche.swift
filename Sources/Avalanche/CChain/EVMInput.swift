//
//  EVMInput.swift
//  
//
//  Created by Ostap Danylovych on 01.09.2021.
//

import Foundation

public struct EVMInput {
    public let address: EthAddress
    public let amount: UInt64
    public let assetID: AssetID
    public let nonce: UInt64
    
    public init(address: EthAddress, amount: UInt64, assetID: AssetID, nonce: UInt64) {
        self.address = address
        self.amount = amount
        self.assetID = assetID
        self.nonce = nonce
    }
}

extension EVMInput: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(address)
            .encode(amount)
            .encode(assetID)
            .encode(nonce)
    }
}
