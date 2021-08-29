//
//  Credentials.swift
//  
//
//  Created by Ostap Danylovych on 29.08.2021.
//

import Foundation

public struct Signature {
    public static let size = 65

    public let data: Data

    public init?(data: Data) {
        guard data.count == Self.size else {
            return nil
        }
        self.data = data
    }
}

extension Signature: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(data, size: Self.size)
    }
}

public class Credential: AvalancheEncodable {
    public class var typeID: TypeID { fatalError("Not supported") }
    
    public let signatures: [Signature]
    
    public init(signatures: [Signature]) {
        self.signatures = signatures
    }
    
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.typeID).encode(signatures)
    }
}

public class SECP256K1Credential: Credential {
    override public class var typeID: TypeID { .secp256K1Credential }
}

public class NFTCredential: Credential {
    override public class var typeID: TypeID { .nftCredential }
}
