//
//  Operations.swift
//  
//
//  Created by Ostap Danylovych on 28.08.2021.
//

import Foundation

public class Operation: AvalancheEncodable, AvalancheDynamicDecodableTypeID, Equatable {
    public class var typeID: TypeID { fatalError("Not supported") }
    
    public init() {}
    
    required public init(dynamic decoder: AvalancheDecoder, typeID: UInt32) throws {
        fatalError("Not supported")
    }
    
    public static func from(decoder: AvalancheDecoder) throws -> Self {
        return try decoder.context.dynamicParser.decode(operation: decoder) as! Self
    }
    
    public func encode(in encoder: AvalancheEncoder) throws {
        fatalError("Not supported")
    }
    
    public func equalTo(rhs: Operation) -> Bool {
        fatalError("Not supported")
    }
    
    public static func == (lhs: Operation, rhs: Operation) -> Bool {
        lhs.equalTo(rhs: rhs)
    }
}

public class SECP256K1MintOperation: Operation, AvalancheDecodable {
    override public class var typeID: TypeID { XChainTypeID.secp256K1MintOperation }
    
    public let addressIndices: [UInt32]
    public let mintOutput: SECP256K1MintOutput
    public let transferOutput: SECP256K1TransferOutput
    
    public init(addressIndices: [UInt32], mintOutput: SECP256K1MintOutput, transferOutput: SECP256K1TransferOutput) {
        self.addressIndices = addressIndices
        self.mintOutput = mintOutput
        self.transferOutput = transferOutput
        super.init()
    }
    
    convenience required public init(dynamic decoder: AvalancheDecoder, typeID: UInt32) throws {
        guard typeID == Self.typeID.rawValue else {
            throw AvalancheDecoderError.dataCorrupted(
                typeID,
                AvalancheDecoderError.Context(path: decoder.path, description: "Wrong typeID")
            )
        }
        self.init(
            addressIndices: try decoder.decode(name: "addressIndices"),
            mintOutput: try decoder.decode(name: "mintOutput"),
            transferOutput: try decoder.decode(name: "transferOutput")
        )
    }
    
    override public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.typeID, name: "typeID")
            .encode(addressIndices, name: "addressIndices")
            .encode(mintOutput, name: "mintOutput")
            .encode(transferOutput, name: "transferOutput")
    }
    
    override public func equalTo(rhs: Operation) -> Bool {
        guard let rhs = rhs as? Self else { return false }
        return addressIndices == rhs.addressIndices
            && mintOutput == rhs.mintOutput
            && transferOutput == rhs.transferOutput
    }
}

public struct NFTMintOperationOutput: Equatable {
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

extension NFTMintOperationOutput: AvalancheCodable {
    public init(from decoder: AvalancheDecoder) throws {
        try self.init(
            locktime: try decoder.decode(name: "locktime"),
            threshold: try decoder.decode(name: "threshold"),
            addresses: try decoder.decode(name: "addresses")
        )
    }

    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(locktime, name: "locktime")
            .encode(threshold, name: "threshold")
            .encode(addresses, name: "addresses")
    }
}

public class NFTMintOperation: Operation, AvalancheDecodable {
    override public class var typeID: TypeID { XChainTypeID.nftMintOperation }
    
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
        super.init()
    }
    
    convenience required public init(dynamic decoder: AvalancheDecoder, typeID: UInt32) throws {
        guard typeID == Self.typeID.rawValue else {
            throw AvalancheDecoderError.dataCorrupted(
                typeID,
                AvalancheDecoderError.Context(path: decoder.path, description: "Wrong typeID")
            )
        }
        try self.init(
            addressIndices: try decoder.decode(name: "addressIndices"),
            groupID: try decoder.decode(name: "groupID"),
            payload: try decoder.decode(name: "payload"),
            outputs: try decoder.decode(name: "outputs")
        )
    }
    
    override public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.typeID, name: "typeID")
            .encode(addressIndices, name: "addressIndices")
            .encode(groupID, name: "groupID")
            .encode(payload, name: "payload")
            .encode(outputs, name: "outputs")
    }
    
    override public func equalTo(rhs: Operation) -> Bool {
        guard let rhs = rhs as? Self else { return false }
        return addressIndices == rhs.addressIndices
            && groupID == rhs.groupID
            && payload == rhs.payload
            && outputs == rhs.outputs
    }
}

public struct NFTTransferOperationOutput: Equatable {
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

extension NFTTransferOperationOutput: AvalancheCodable {
    public init(from decoder: AvalancheDecoder) throws {
        try self.init(
            groupID: try decoder.decode(name: "groupID"),
            payload: try decoder.decode(name: "payload"),
            locktime: try decoder.decode(name: "locktime"),
            threshold: try decoder.decode(name: "threshold"),
            addresses: try decoder.decode(name: "addresses")
        )
    }

    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(groupID, name: "groupID")
            .encode(payload, name: "payload")
            .encode(locktime, name: "locktime")
            .encode(threshold, name: "threshold")
            .encode(addresses, name: "addresses")
    }
}

public class NFTTransferOperation: Operation, AvalancheDecodable {
    override public class var typeID: TypeID { XChainTypeID.nftTransferOperation }
    
    public let addressIndices: [UInt32]
    public let nftTransferOutput: NFTTransferOperationOutput
    
    public init(addressIndices: [UInt32], nftTransferOutput: NFTTransferOperationOutput) {
        self.addressIndices = addressIndices
        self.nftTransferOutput = nftTransferOutput
        super.init()
    }
    
    convenience required public init(dynamic decoder: AvalancheDecoder, typeID: UInt32) throws {
        guard typeID == Self.typeID.rawValue else {
            throw AvalancheDecoderError.dataCorrupted(
                typeID,
                AvalancheDecoderError.Context(path: decoder.path, description: "Wrong typeID")
            )
        }
        self.init(
            addressIndices: try decoder.decode(name: "addressIndices"),
            nftTransferOutput: try decoder.decode(name: "nftTransferOutput")
        )
    }
    
    override public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.typeID, name: "typeID")
            .encode(addressIndices, name: "addressIndices")
            .encode(nftTransferOutput, name: "nftTransferOutput")
    }
    
    override public func equalTo(rhs: Operation) -> Bool {
        guard let rhs = rhs as? Self else { return false }
        return addressIndices == rhs.addressIndices
            && nftTransferOutput == rhs.nftTransferOutput
    }
}
