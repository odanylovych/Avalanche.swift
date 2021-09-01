//
//  PChainOutputs.swift
//  
//
//  Created by Ostap Danylovych on 01.09.2021.
//

import Foundation

public class SECP256K1OutputOwners: Output {
    override public class var typeID: TypeID { PChainTypeID.secp256K1OutputOwners }
    
    public let locktime: Date
    public let threshold: UInt32
    public let addresses: [Address]
    
    public init(locktime: Date, threshold: UInt32, addresses: [Address]) throws {
        guard threshold <= addresses.count else {
            throw MalformedTransactionError.outOfRange(
                threshold,
                expected: 0...addresses.count,
                name: "Threshold",
                description: "Must be less than or equal to the length of Addresses"
            )
        }
        self.locktime = locktime
        self.threshold = threshold
        self.addresses = addresses
    }
    
    override public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.typeID)
            .encode(locktime)
            .encode(threshold)
            .encode(addresses)
    }
}