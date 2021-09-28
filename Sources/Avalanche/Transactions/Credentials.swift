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

public class Credential: AvalancheEncodable, AvalancheDynamicDecodableTypeID, Equatable {
    public class var typeID: TypeID { fatalError("Not supported") }
    
    public let signatures: [Signature]
    
    required public init(signatures: [Signature]) {
        self.signatures = signatures
    }
    
    required public init(dynamic decoder: AvalancheDecoder, typeID: UInt32) throws {
        fatalError("Not supported")
    }
    
    public static func from(decoder: AvalancheDecoder) throws -> Self {
        return try decoder.context.dynamicParser.decode(credential: decoder) as! Self
    }
    
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.typeID, name: "typeID")
            .encode(signatures, name: "signatures")
    }
    
    public static func == (lhs: Credential, rhs: Credential) -> Bool {
        lhs.signatures == rhs.signatures
    }
}

public class SECP256K1Credential: Credential, AvalancheDecodable {
    override public class var typeID: TypeID { CommonTypeID.secp256K1Credential }
    
    convenience required public init(dynamic decoder: AvalancheDecoder, typeID: UInt32) throws {
        guard typeID == Self.typeID.rawValue else {
            throw AvalancheDecoderError.dataCorrupted(
                typeID,
                AvalancheDecoderError.Context(path: decoder.path, description: "Wrong typeID")
            )
        }
        self.init(signatures: try decoder.decode())
    }
}
