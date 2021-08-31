//
//  Operations.swift
//  
//
//  Created by Ostap Danylovych on 28.08.2021.
//

import Foundation

public class Operation: AvalancheEncodable {
    public class var typeID: TypeID { fatalError("Not supported") }
    
    public func encode(in encoder: AvalancheEncoder) throws {
        fatalError("Not supported")
    }
}

public class SECP256K1MintOperation: Operation {
    override public class var typeID: TypeID { CommonTypeID.secp256K1MintOperation }
    
    public let addressIndices: [UInt32]
    public let mintOutput: SECP256K1MintOutput
    public let transferOutput: SECP256K1TransferOutput
    
    public init(addressIndices: [UInt32], mintOutput: SECP256K1MintOutput, transferOutput: SECP256K1TransferOutput) {
        self.addressIndices = addressIndices
        self.mintOutput = mintOutput
        self.transferOutput = transferOutput
    }
    
    override public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.typeID)
            .encode(addressIndices)
            .encode(mintOutput)
            .encode(transferOutput)
    }
}

public struct NFTMintOperationOutput {
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
}

extension NFTMintOperationOutput: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(locktime)
            .encode(threshold)
            .encode(addresses)
    }
}

public class NFTMintOperation: Operation {
    override public class var typeID: TypeID { CommonTypeID.nftMintOperation }
    
    public let addressIndices: [UInt32]
    public let groupID: UInt32
    public let payload: Data
    public let outputs: [NFTMintOperationOutput]
    
    public init(addressIndices: [UInt32], groupID: UInt32, payload: Data, outputs: [NFTMintOperationOutput]) throws {
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
    
    override public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.typeID)
            .encode(addressIndices)
            .encode(groupID)
            .encode(payload)
            .encode(outputs)
    }
}

public struct NFTTransferOperationOutput {
    public let groupID: UInt32
    public let payload: Data
    public let locktime: Date
    public let threshold: UInt32
    public let addresses: [Address]
    
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
        self.addresses = addresses
    }
}

extension NFTTransferOperationOutput: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(groupID)
            .encode(payload)
            .encode(locktime)
            .encode(threshold)
            .encode(addresses)
    }
}

public class NFTTransferOperation: Operation {
    override public class var typeID: TypeID { CommonTypeID.nftTransferOperation }
    
    public let addressIndices: [UInt32]
    public let nftTransferOutput: NFTTransferOperationOutput
    
    public init(addressIndices: [UInt32], nftTransferOutput: NFTTransferOperationOutput) {
        self.addressIndices = addressIndices
        self.nftTransferOutput = nftTransferOutput
    }
    
    override public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.typeID)
            .encode(addressIndices)
            .encode(nftTransferOutput)
    }
}
