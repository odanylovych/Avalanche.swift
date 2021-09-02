//
//  EVMOutput.swift
//  
//
//  Created by Ostap Danylovych on 01.09.2021.
//

import Foundation

public struct EVMOutput {
    public let address: EthAddress
    public let amount: UInt64
    public let assetID: AssetID
    
    public init(address: EthAddress, amount: UInt64, assetID: AssetID) {
        self.address = address
        self.amount = amount
        self.assetID = assetID
    }
}

extension EVMOutput: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(address, name: "address")
            .encode(amount, name: "amount")
            .encode(assetID, name: "assetID")
    }
}
