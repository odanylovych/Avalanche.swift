//
//  PChainOutputs.swift
//  
//
//  Created by Ostap Danylovych on 01.09.2021.
//

import Foundation

public class SECP256K1OutputOwners: Output, AvalancheDecodable {
    override public class var typeID: TypeID { PChainTypeID.secp256K1OutputOwners }
    
    public init(locktime: Date, threshold: UInt32, addresses: [Address]) throws {
        try super.init(addresses: addresses, locktime: locktime, threshold: threshold)
    }
    
    convenience required public init(amount: UInt64, locktime: Date, threshold: UInt32, addresses: [Address]) throws {
        fatalError("Not supported")
    }
    
    convenience required public init(dynamic decoder: AvalancheDecoder, typeID: UInt32) throws {
        guard typeID == Self.typeID.rawValue else {
            throw AvalancheDecoderError.dataCorrupted(
                typeID,
                AvalancheDecoderError.Context(path: decoder.path, description: "Wrong typeID")
            )
        }
        try self.init(
            locktime: try decoder.decode(name: "locktime"),
            threshold: try decoder.decode(name: "threshold"),
            addresses: try decoder.decode(name: "addresses")
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
