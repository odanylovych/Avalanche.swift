//
//  XChainCredentials.swift
//  
//
//  Created by Ostap Danylovych on 01.09.2021.
//

import Foundation

public class NFTCredential: Credential, AvalancheDecodable {
    override public class var typeID: TypeID { XChainTypeID.nftCredential }
    
    convenience required public init(dynamic decoder: AvalancheDecoder, typeID: UInt32) throws {
        guard typeID == Self.typeID.rawValue else {
            throw AvalancheDecoderError.dataCorrupted(typeID, description: "Wrong typeID")
        }
        self.init(signatures: try decoder.decode())
    }
}
