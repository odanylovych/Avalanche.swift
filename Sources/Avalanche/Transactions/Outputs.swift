//
//  Outputs.swift
//  
//
//  Created by Ostap Danylovych on 26.08.2021.
//

import Foundation

public class Output: AvalancheCodable {
    public class var typeID: TypeID { fatalError("Not supported") }
    
    public let addresses: [Address]
    
    public init(addresses: [Address]) {
        self.addresses = addresses
    }
    
    required public init(from decoder: AvalancheDecoder) throws {
        fatalError("Not supported")
    }
    
    public static func from(decoder: AvalancheDecoder) throws -> Output {
        let typeID = try UInt32(from: decoder)
        switch typeID {
        case CommonTypeID.secp256K1TransferOutput.rawValue:
            return try SECP256K1TransferOutput(from: decoder)
        case XChainTypeID.secp256K1MintOutput.rawValue:
            return try SECP256K1MintOutput(from: decoder)
        case XChainTypeID.nftTransferOutput.rawValue:
            return try NFTTransferOutput(from: decoder)
        case XChainTypeID.nftMintOutput.rawValue:
            return try NFTMintOutput(from: decoder)
        case PChainTypeID.secp256K1OutputOwners.rawValue:
            return try SECP256K1OutputOwners(from: decoder)
        default:
            throw AvalancheDecoderError.dataCorrupted(typeID, description: "Wrong Output typeID")
        }
    }
    
    public func encode(in encoder: AvalancheEncoder) throws {
        fatalError("Not supported")
    }
}

public class SECP256K1TransferOutput: Output {
    override public class var typeID: TypeID { CommonTypeID.secp256K1TransferOutput }
    
    public let amount: UInt64
    public let locktime: Date
    public let threshold: UInt32
    
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
        super.init(addresses: addresses)
    }

    convenience required public init(from decoder: AvalancheDecoder) throws {
        try self.init(
            amount: try UInt64(from: decoder),
            locktime: try Date(from: decoder),
            threshold: try UInt32(from: decoder),
            addresses: try [Address](from: decoder)
        )
    }

    override public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.typeID, name: "typeID")
            .encode(amount, name: "amount")
            .encode(locktime, name: "locktime")
            .encode(threshold, name: "threshold")
            .encode(addresses, name: "addresses")
    }
}
