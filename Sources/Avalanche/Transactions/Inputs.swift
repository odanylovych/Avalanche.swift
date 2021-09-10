//
//  Inputs.swift
//  
//
//  Created by Ostap Danylovych on 28.08.2021.
//

import Foundation

public class Input: AvalancheEncodable {
    public class var typeID: TypeID { fatalError("Not supported") }
    
    public let addressIndices: [UInt32]
    
    public init(addressIndices: [UInt32]) {
        self.addressIndices = addressIndices
    }
    
    public func credentialType() -> Credential.Type {
        fatalError("Not supported")
    }
    
    public func encode(in encoder: AvalancheEncoder) throws {
        fatalError("Not supported")
    }
}

public class SECP256K1TransferInput: Input {
    override public class var typeID: TypeID { CommonTypeID.secp256K1TransferInput }
    
    public let amount: UInt64
    
    public init(amount: UInt64, addressIndices: [UInt32]) throws {
        guard amount > 0 else {
            throw MalformedTransactionError.wrongValue(amount, name: "Amount", message: "Must be positive")
        }
        self.amount = amount
        super.init(addressIndices: addressIndices)
    }
    
    override public func credentialType() -> Credential.Type {
        SECP256K1Credential.self
    }
    
    override public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.typeID, name: "typeID")
            .encode(amount, name: "amount")
            .encode(addressIndices, name: "addressIndices")
    }
}
