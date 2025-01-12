//
//  Outputs.swift
//  
//
//  Created by Ostap Danylovych on 26.08.2021.
//

import Foundation

public class Output: AvalancheEncodable, AvalancheDynamicDecodableTypeID, Equatable {
    public class var typeID: TypeID { fatalError("Not supported") }
    
    public let addresses: [Address]
    public let locktime: Date
    public let threshold: UInt32
    
    public init(addresses: [Address], locktime: Date, threshold: UInt32) throws {
        guard threshold <= addresses.count else {
            throw MalformedTransactionError.outOfRange(
                threshold,
                expected: 0...addresses.count,
                name: "Threshold",
                description: "Must be less than or equal to the length of Addresses"
            )
        }
        self.addresses = addresses
        self.locktime = locktime
        self.threshold = threshold
    }
    
    required public init(dynamic decoder: AvalancheDecoder, typeID: UInt32) throws {
        fatalError("Not supported")
    }
    
    required public init(
        amount: UInt64,
        locktime: Date,
        threshold: UInt32,
        addresses: [Address]
    ) throws {
        fatalError("Not supported")
    }
    
    public func getAddressIndices(for addresses: [Address]) -> [UInt32] {
        Date() > locktime ? Array(
            self.addresses.enumerated()
                .filter { addresses.contains($0.element) }
                .map { UInt32($0.offset) }
                .prefix(Int(threshold))
        ) : []
    }
    
    public static func from(decoder: AvalancheDecoder) throws -> Self {
        return try decoder.context.dynamicParser.decode(output: decoder) as! Self
    }
    
    public func encode(in encoder: AvalancheEncoder) throws {
        fatalError("Not supported")
    }
    
    public func equalTo(rhs: Output) -> Bool {
        fatalError("Not supported")
    }
    
    public static func == (lhs: Output, rhs: Output) -> Bool {
        lhs.equalTo(rhs: rhs)
    }
}

public class SECP256K1TransferOutput: Output, AvalancheDecodable {
    override public class var typeID: TypeID { CommonTypeID.secp256K1TransferOutput }
    
    public let amount: UInt64
    
    required public init(amount: UInt64, locktime: Date, threshold: UInt32, addresses: [Address]) throws {
        guard amount > 0 else {
            throw MalformedTransactionError.wrongValue(amount, name: "Amount", message: "Must be positive")
        }
        self.amount = amount
        try super.init(addresses: addresses, locktime: locktime, threshold: threshold)
    }
    
    convenience required public init(dynamic decoder: AvalancheDecoder, typeID: UInt32) throws {
        guard typeID == Self.typeID.rawValue else {
            throw AvalancheDecoderError.dataCorrupted(
                typeID,
                AvalancheDecoderError.Context(path: decoder.path, description: "Wrong typeID")
            )
        }
        try self.init(
            amount: try decoder.decode(name: "amount"),
            locktime: try decoder.decode(name: "locktime"),
            threshold: try decoder.decode(name: "threshold"),
            addresses: try decoder.decode(name: "addresses")
        )
    }
    
    override public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.typeID, name: "typeID")
            .encode(amount, name: "amount")
            .encode(locktime, name: "locktime")
            .encode(threshold, name: "threshold")
            .encode(addresses, name: "addresses")
    }
    
    override public func equalTo(rhs: Output) -> Bool {
        guard let rhs = rhs as? Self else { return false }
        return amount == rhs.amount
            && locktime == rhs.locktime
            && threshold == rhs.threshold
            && addresses == rhs.addresses
    }
}
