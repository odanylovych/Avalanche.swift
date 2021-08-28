//
//  Inputs.swift
//  
//
//  Created by Ostap Danylovych on 28.08.2021.
//

import Foundation

public enum InputTypeID: UInt32 {
    case secp256K1Transfer = 0x00000005
}

extension InputTypeID: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(rawValue)
    }
}

public protocol Input: AvalancheEncodable {
    static var typeID: InputTypeID { get }
}

public struct SECP256K1TransferInput: Input {
    public static let typeID = InputTypeID.secp256K1Transfer
    
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

extension SECP256K1TransferInput: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.typeID)
            .encode(amount)
            .encode(addressIndices)
    }
}
