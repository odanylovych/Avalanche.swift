//
//  TypeID.swift
//  
//
//  Created by Ostap Danylovych on 29.08.2021.
//

import Foundation

public protocol TypeID: AvalancheEncodable {
    var rawValue: UInt32 { get }
}

extension TypeID {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(rawValue)
    }
}

public enum CommonTypeID: UInt32, TypeID, CaseIterable {
    // Inputs
    case secp256K1TransferInput = 0x00000005
    
    // Outputs
    case secp256K1TransferOutput = 0x00000007
    
    // Credentials
    case secp256K1Credential = 0x00000009
    
    // Transactions
    case baseTransaction = 0x00000000
}
