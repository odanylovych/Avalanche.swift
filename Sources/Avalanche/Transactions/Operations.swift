//
//  Operations.swift
//  
//
//  Created by Ostap Danylovych on 28.08.2021.
//

import Foundation

public enum OpTypeID: UInt32 {
    case secp256K1MintOp = 0x00000008
    case nftMintOp = 0x0000000c
    case nftTransferOp = 0x0000000d
}

extension OpTypeID: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(rawValue)
    }
}

public protocol Operation: AvalancheEncodable {
    static var typeID: OpTypeID { get }
}

public struct SECP256K1MintOperation: Operation {
    public static let typeID = OpTypeID.secp256K1MintOp
    
    public let addressIndices: [UInt32]
    public let mintOutput: SECP256K1MintOutput
    public let transferOutput: SECP256K1TransferOutput
    
    public init(addressIndices: [UInt32], mintOutput: SECP256K1MintOutput, transferOutput: SECP256K1TransferOutput) {
        self.addressIndices = addressIndices
        self.mintOutput = mintOutput
        self.transferOutput = transferOutput
    }
}

extension SECP256K1MintOperation {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.typeID)
            .encode(addressIndices)
            .encode(mintOutput)
            .encode(transferOutput)
    }
}

public struct NFTMintOpOutput {
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

extension NFTMintOpOutput: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(locktime)
            .encode(threshold)
            .encode(addresses)
    }
}

public struct NFTMintOp: Operation {
    public static let typeID = OpTypeID.nftMintOp
    
    public let addressIndices: [UInt32]
    public let groupID: UInt32
    public let payload: Data
    public let outputs: [NFTMintOpOutput]
    
    public init(addressIndices: [UInt32], groupID: UInt32, payload: Data, outputs: [NFTMintOpOutput]) throws {
        guard payload.count <= 1024 else {
            throw MalformedTransactionError.outOfRange(
                payload.count,
                expected: 0...1024,
                name: "Payload length"
            )
        }
        self.addressIndices = addressIndices
        self.groupID = groupID
        self.payload = payload
        self.outputs = outputs
    }
}

extension NFTMintOp {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.typeID)
            .encode(addressIndices)
            .encode(groupID)
            .encode(payload)
            .encode(outputs)
    }
}

public struct NFTTransferOpOutput {
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

extension NFTTransferOpOutput: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(groupID)
            .encode(payload)
            .encode(locktime)
            .encode(threshold)
            .encode(addresses)
    }
}

public struct NFTTransferOp: Operation {
    public static let typeID = OpTypeID.nftTransferOp
    
    public let addressIndices: [UInt32]
    public let nftTransferOutput: NFTTransferOpOutput
    
    public init(addressIndices: [UInt32], nftTransferOutput: NFTTransferOpOutput) {
        self.addressIndices = addressIndices
        self.nftTransferOutput = nftTransferOutput
    }
}

extension NFTTransferOp {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.typeID)
            .encode(addressIndices)
            .encode(nftTransferOutput)
    }
}
