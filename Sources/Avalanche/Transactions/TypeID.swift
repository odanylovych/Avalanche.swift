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
    case secp256K1MintOutput = 0x00000006
    
    // Operations
    case secp256K1MintOperation = 0x00000008
    
    // Credentials
    case secp256K1Credential = 0x00000009
    
    // Transactions
    case baseTransaction = 0x00000000
    case createAssetTransaction = 0x00000001
    case operationTransaction = 0x00000002
}

public enum XChainTypeID: UInt32, TypeID, CaseIterable {
    // Outputs
    case nftTransferOutput = 0x0000000b
    case nftMintOutput = 0x0000000a
    
    // Operations
    case nftMintOperation = 0x0000000c
    case nftTransferOperation = 0x0000000d
    
    // Credentials
    case nftCredential = 0x0000000e
    
    // Transactions
    case importTransaction = 0x00000003
    case exportTransaction = 0x00000004
}

public enum PChainTypeID: UInt32, TypeID, CaseIterable {
    // Outputs
    case secp256K1OutputOwners = 0x0000000b
    
    // Transactions
    case addValidatorTransaction = 0x0000000c
    case addSubnetValidatorTransaction = 0x0000000d
    case addDelegatorTransaction = 0x0000000e
    case createSubnetTransaction = 0x00000010
    case importTransaction = 0x00000011
    case exportTransaction = 0x00000012
    
    case subnetAuth = 0x0000000a
    
    case stakeableLockedInput = 0x00000015
    case stakeableLockedOutput = 0x00000016
}
