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

public class Credential: AvalancheCodable {
    public class var typeID: TypeID { fatalError("Not supported") }
    
    public let signatures: [Signature]
    
    required public init(signatures: [Signature]) {
        self.signatures = signatures
    }
    
    required public init(from decoder: AvalancheDecoder) throws {
        fatalError("Not supported")
    }
    
    public static func from(decoder: AvalancheDecoder) throws -> Credential {
        let typeID: UInt32 = try decoder.decode()
        switch typeID {
        case CommonTypeID.secp256K1Credential.rawValue:
            return try decoder.decode(SECP256K1Credential.self)
        case XChainTypeID.nftCredential.rawValue:
            return try decoder.decode(NFTCredential.self)
        default:
            throw AvalancheDecoderError.dataCorrupted(typeID, description: "Wrong Credential typeID")
        }
    }
    
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.typeID, name: "typeID")
            .encode(signatures, name: "signatures")
    }
}

public class SECP256K1Credential: Credential {
    override public class var typeID: TypeID { CommonTypeID.secp256K1Credential }
    
    convenience required public init(from decoder: AvalancheDecoder) throws {
        self.init(signatures: try decoder.decode())
    }
}
