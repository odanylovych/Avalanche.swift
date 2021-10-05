//
//  Inputs.swift
//  
//
//  Created by Ostap Danylovych on 28.08.2021.
//

import Foundation

public class Input: AvalancheEncodable, AvalancheDynamicDecodableTypeID, Equatable {
    public class var typeID: TypeID { fatalError("Not supported") }
    
    public let addressIndices: [UInt32]
    
    public init(addressIndices: [UInt32]) {
        self.addressIndices = addressIndices
    }
    
    required public init(dynamic decoder: AvalancheDecoder, typeID: UInt32) throws {
        fatalError("Not supported")
    }
    
    public static func from(decoder: AvalancheDecoder) throws -> Self {
        return try decoder.context.dynamicParser.decode(input: decoder) as! Self
    }
    
    public func credentialType() -> Credential.Type {
        fatalError("Not supported")
    }
    
    public func encode(in encoder: AvalancheEncoder) throws {
        fatalError("Not supported")
    }
    
    public func equalTo(rhs: Input) -> Bool {
        fatalError("Not supported")
    }
    
    public static func == (lhs: Input, rhs: Input) -> Bool {
        lhs.equalTo(rhs: rhs)
    }
}

public class SECP256K1TransferInput: Input, AvalancheDecodable {
    override public class var typeID: TypeID { CommonTypeID.secp256K1TransferInput }
    
    public let amount: UInt64
    
    public init(amount: UInt64, addressIndices: [UInt32]) throws {
        guard amount > 0 else {
            throw MalformedTransactionError.wrongValue(amount, name: "Amount", message: "Must be positive")
        }
        self.amount = amount
        super.init(addressIndices: addressIndices)
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
            addressIndices: try decoder.decode(name: "addressIndices")
        )
    }
    
    override public func credentialType() -> Credential.Type {
        SECP256K1Credential.self
    }
    
    override public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.typeID, name: "typeID")
            .encode(amount, name: "amount")
            .encode(addressIndices, name: "addressIndices")
    }
    
    override public func equalTo(rhs: Input) -> Bool {
        guard let rhs = rhs as? Self else { return false }
        return amount == rhs.amount
            && addressIndices == rhs.addressIndices
    }
}
