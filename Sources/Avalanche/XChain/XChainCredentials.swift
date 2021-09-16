//
//  XChainCredentials.swift
//  
//
//  Created by Ostap Danylovych on 01.09.2021.
//

import Foundation

public class NFTCredential: Credential {
    override public class var typeID: TypeID { XChainTypeID.nftCredential }
    
    convenience required public init(from decoder: AvalancheDecoder) throws {
        self.init(signatures: try [Signature](from: decoder))
    }
}
