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
        let typeID: UInt32 = try decoder.decode()
        switch typeID {
        case CommonTypeID.secp256K1TransferOutput.rawValue:
            return try decoder.decode(SECP256K1TransferOutput.self)
        case XChainTypeID.secp256K1MintOutput.rawValue:
            return try decoder.decode(SECP256K1MintOutput.self)
        case XChainTypeID.nftTransferOutput.rawValue:
            return try decoder.decode(NFTTransferOutput.self)
        case XChainTypeID.nftMintOutput.rawValue:
            return try decoder.decode(NFTMintOutput.self)
        case PChainTypeID.secp256K1OutputOwners.rawValue:
            return try decoder.decode(SECP256K1OutputOwners.self)
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
            amount: try decoder.decode(),
            locktime: try decoder.decode(),
            threshold: try decoder.decode(),
            addresses: try decoder.decode()
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
