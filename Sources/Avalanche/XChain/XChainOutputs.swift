//
//  XChainOutputs.swift
//  
//
//  Created by Ostap Danylovych on 01.09.2021.
//

import Foundation

public class SECP256K1MintOutput: Output, AvalancheDecodable {
    override public class var typeID: TypeID { XChainTypeID.secp256K1MintOutput }
    
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

public class NFTTransferOutput: Output, AvalancheDecodable {
    override public class var typeID: TypeID { XChainTypeID.nftTransferOutput }
    
    public let groupID: UInt32
    public let payload: Data
    public let locktime: Date
    public let threshold: UInt32
    
    public init(groupID: UInt32, payload: Data, locktime: Date, threshold: UInt32, addresses: [Address]) throws {
        guard payload.count <= 1024 else {
            throw MalformedTransactionError.outOfRange(
                payload.count,
                expected: 0...1024,
                name: "Payload length"
            )
        }
        guard threshold <= addresses.count else {
            throw MalformedTransactionError.outOfRange(
                threshold,
                expected: 0...addresses.count,
                name: "Threshold",
                description: "Must be less than or equal to the length of Addresses"
            )
        }
        self.groupID = groupID
        self.payload = payload
        self.locktime = locktime
        self.threshold = threshold
        super.init(addresses: addresses)
    }
    
    convenience required public init(dynamic decoder: AvalancheDecoder, typeID: UInt32) throws {
        guard typeID == Self.typeID.rawValue else {
            throw AvalancheDecoderError.dataCorrupted(
                typeID,
                AvalancheDecoderError.Context(path: decoder.path, description: "Wrong typeID")
            )
        }
        try self.init(
            groupID: try decoder.decode(name: "groupID"),
            payload: try decoder.decode(name: "payload"),
            locktime: try decoder.decode(name: "locktime"),
            threshold: try decoder.decode(name: "threshold"),
            addresses: try decoder.decode(name: "addresses")
        )
    }
    
    override public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.typeID, name: "typeID")
            .encode(groupID, name: "groupID")
            .encode(payload, name: "payload")
            .encode(locktime, name: "locktime")
            .encode(threshold, name: "threshold")
            .encode(addresses, name: "addresses")
    }
    
    override public func equalTo(rhs: Output) -> Bool {
        guard let rhs = rhs as? Self else { return false }
        return groupID == rhs.groupID
            && payload == rhs.payload
            && locktime == rhs.locktime
            && threshold == rhs.threshold
            && addresses == rhs.addresses
    }
}

public class NFTMintOutput: Output, AvalancheDecodable {
    override public class var typeID: TypeID { XChainTypeID.nftMintOutput }
    
    public let groupID: UInt32
    public let locktime: Date
    public let threshold: UInt32
    
    public init(groupID: UInt32, locktime: Date, threshold: UInt32, addresses: [Address]) throws {
        guard threshold <= addresses.count else {
            throw MalformedTransactionError.outOfRange(
                threshold,
                expected: 0...addresses.count,
                name: "Threshold",
                description: "Must be less than or equal to the length of Addresses"
            )
        }
        self.groupID = groupID
        self.locktime = locktime
        self.threshold = threshold
        super.init(addresses: addresses)
    }
    
    convenience required public init(dynamic decoder: AvalancheDecoder, typeID: UInt32) throws {
        guard typeID == Self.typeID.rawValue else {
            throw AvalancheDecoderError.dataCorrupted(
                typeID,
                AvalancheDecoderError.Context(path: decoder.path, description: "Wrong typeID")
            )
        }
        try self.init(
            groupID: try decoder.decode(name: "groupID"),
            locktime: try decoder.decode(name: "locktime"),
            threshold: try decoder.decode(name: "threshold"),
            addresses: try decoder.decode(name: "addresses")
        )
    }
    
    override public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.typeID, name: "typeID")
            .encode(groupID, name: "groupID")
            .encode(locktime, name: "locktime")
            .encode(threshold, name: "threshold")
            .encode(addresses, name: "addresses")
    }
    
    override public func equalTo(rhs: Output) -> Bool {
        guard let rhs = rhs as? Self else { return false }
        return groupID == rhs.groupID
            && locktime == rhs.locktime
            && threshold == rhs.threshold
            && addresses == rhs.addresses
    }
}
