//
//  Inputs.swift
//  
//
//  Created by Ostap Danylovych on 28.08.2021.
//

import Foundation

public protocol Input: AvalancheEncodable {
    static var typeID: TypeID { get }
}

public struct SECP256K1TransferInput: Input {
    public static let typeID: TypeID = .secp256K1TransferInput
    
    public let amount: UInt64
    public let addressIndices: [UInt32]
    
    public init(amount: UInt64, addressIndices: [UInt32]) throws {
        guard amount > 0 else {
            throw MalformedTransactionError.wrongValue(amount, name: "Amount", message: "Must be positive")
        }
        self.amount = amount
        self.addressIndices = addressIndices
    }
}

extension SECP256K1TransferInput {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.typeID)
            .encode(amount)
            .encode(addressIndices)
    }
}
