//
//  PChainOutputs.swift
//  
//
//  Created by Ostap Danylovych on 01.09.2021.
//

import Foundation

public class SECP256K1OutputOwners: Output, AvalancheDecodable {
    override public class var typeID: TypeID { PChainTypeID.secp256K1OutputOwners }
    
    public let locktime: Date
    public let threshold: UInt32
    
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
        super.init(addresses: addresses)
    }
    
    convenience required public init(dynamic decoder: AvalancheDecoder, typeID: UInt32) throws {
        guard typeID == Self.typeID.rawValue else {
            throw AvalancheDecoderError.dataCorrupted(typeID, description: "Wrong typeID")
        }
        try self.init(
            locktime: try decoder.decode(),
            threshold: try decoder.decode(),
            addresses: try decoder.decode()
        )
    }
    
    override public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.typeID, name: "typeID")
            .encode(locktime, name: "locktime")
            .encode(threshold, name: "threshold")
            .encode(addresses, name: "addresses")
    }
    
    override public func equalTo(rhs: Output) -> Bool {
        guard let rhs = rhs as? Self else { return false }
        return locktime == rhs.locktime
            && threshold == rhs.threshold
            && addresses == rhs.addresses
    }
}
