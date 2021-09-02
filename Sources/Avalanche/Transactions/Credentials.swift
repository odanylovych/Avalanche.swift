//
//  Credentials.swift
//  
//
//  Created by Ostap Danylovych on 29.08.2021.
//

import Foundation

public struct Signature: ID {
    public static let size = 65
    
    public let raw: Data
    
    public init(raw: Data) {
        self.raw = raw
    }
}

public class Credential: AvalancheEncodable {
    public class var typeID: TypeID { fatalError("Not supported") }
    
    public let signatures: [Signature]
    
    public init(signatures: [Signature]) {
        self.signatures = signatures
    }
    
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.typeID, name: "typeID")
            .encode(signatures, name: "signatures")
    }
}

public class SECP256K1Credential: Credential {
    override public class var typeID: TypeID { CommonTypeID.secp256K1Credential }
}
