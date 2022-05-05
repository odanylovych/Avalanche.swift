//
//  EVMOutput.swift
//  
//
//  Created by Ostap Danylovych on 01.09.2021.
//

import Foundation
#if !COCOAPODS
import web3swift
#endif

public struct EVMOutput: Equatable {
    public let address: EthereumAddress
    public let amount: UInt64
    public let assetID: AssetID
    
    public init(address: EthereumAddress, amount: UInt64, assetID: AssetID) {
        self.address = address
        self.amount = amount
        self.assetID = assetID
    }
}

extension EVMOutput: AvalancheCodable {
    public init(from decoder: AvalancheDecoder) throws {
        self.init(
            address: try decoder.decode(name: "address"),
            amount: try decoder.decode(name: "amount"),
            assetID: try decoder.decode(name: "assetID")
        )
    }
    
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(address, name: "address")
            .encode(amount, name: "amount")
            .encode(assetID, name: "assetID")
    }
}
