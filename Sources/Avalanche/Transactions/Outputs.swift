//
//  Outputs.swift
//  
//
//  Created by Ostap Danylovych on 26.08.2021.
//

import Foundation

public class Output: AvalancheEncodable {
    public class var typeID: TypeID { fatalError("Not supported") }
    
    public func encode(in encoder: AvalancheEncoder) throws {
        fatalError("Not supported")
    }
}

public class SECP256K1TransferOutput: Output {
    override public class var typeID: TypeID { CommonTypeID.secp256K1TransferOutput }
    
    public let amount: UInt64
    public let locktime: Date
    public let threshold: UInt32
    public let addresses: [Address]
    
    public init(amount: UInt64, locktime: Date, threshold: UInt32, addresses: [Address]) throws {
        guard amount > 0 else {
            throw MalformedTransactionError.wrongValue(amount, name: "Amount", message: "Must be positive")
        }
        guard threshold <= addresses.count else {
            throw MalformedTransactionError.outOfRange(
                threshold,
                expected: 0...addresses.count,
                name: "Threshold",
                description: "Must be less than or equal to the length of Addresses"
            )
        }
        self.amount = amount
        self.locktime = locktime
        self.threshold = threshold
        self.addresses = addresses
    }
    
    override public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.typeID)
            .encode(amount)
            .encode(locktime)
            .encode(threshold)
            .encode(addresses)
    }
}
