//
//  Outputs.swift
//  
//
//  Created by Ostap Danylovych on 26.08.2021.
//

import Foundation

public protocol Output: AvalancheEncodable {
    static var typeID: TypeID { get }
}

public struct SECP256K1TransferOutput: Output {
    public static let typeID: TypeID = .secp256K1TransferOutput
    
    public let amount: UInt64
    public let locktime: UInt64
    public let threshold: UInt32
    public let addresses: [Address]
    
    public init(amount: UInt64, locktime: UInt64, threshold: UInt32, addresses: [Address]) throws {
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
}

extension SECP256K1TransferOutput {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.typeID)
            .encode(amount)
            .encode(locktime)
            .encode(threshold)
            .encode(addresses)
    }
}

public struct SECP256K1MintOutput: Output {
    public static let typeID: TypeID = .secp256K1MintOutput
    
    public let locktime: UInt64
    public let threshold: UInt32
    public let addresses: [Address]
    
    public init(locktime: UInt64, threshold: UInt32, addresses: [Address]) throws {
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
}

extension SECP256K1MintOutput {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.typeID)
            .encode(locktime)
            .encode(threshold)
            .encode(addresses)
    }
}

public struct NFTTransferOutput: Output {
    public static let typeID: TypeID = .nftTransferOutput
    
    public let groupID: UInt32
    public let payload: Data
    public let locktime: UInt64
    public let threshold: UInt32
    public let addresses: [Address]
    
    public init(groupID: UInt32, payload: Data, locktime: UInt64, threshold: UInt32, addresses: [Address]) throws {
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
        self.addresses = addresses
    }
}

extension NFTTransferOutput {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.typeID)
            .encode(groupID)
            .encode(payload)
            .encode(locktime)
            .encode(threshold)
            .encode(addresses)
    }
}

public struct NFTMintOutput: Output {
    public static let typeID: TypeID = .nftMintOutput
    
    public let groupID: UInt32
    public let locktime: UInt64
    public let threshold: UInt32
    public let addresses: [Address]
    
    public init(groupID: UInt32, locktime: UInt64, threshold: UInt32, addresses: [Address]) throws {
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
        self.addresses = addresses
    }
}

extension NFTMintOutput {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.typeID)
            .encode(groupID)
            .encode(locktime)
            .encode(threshold)
            .encode(addresses)
    }
}
