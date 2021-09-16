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

extension EVMInput: AvalancheCodable {
    public init(from decoder: AvalancheDecoder) throws {
        self.init(
            address: try EthAddress(from: decoder),
            amount: try UInt64(from: decoder),
            assetID: try AssetID(from: decoder),
            nonce: try UInt64(from: decoder)
        )
    }
    
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(address, name: "address")
            .encode(amount, name: "amount")
            .encode(assetID, name: "assetID")
            .encode(nonce, name: "nonce")
    }
}
