//
//  XChainTypeID.swift
//  
//
//  Created by Ostap Danylovych on 01.09.2021.
//

import Foundation

public enum XChainTypeID: UInt32, TypeID, CaseIterable {
    // Outputs
    case secp256K1MintOutput = 0x00000006
    case nftTransferOutput = 0x0000000b
    case nftMintOutput = 0x0000000a
    
    // Operations
    case secp256K1MintOperation = 0x00000008
    case nftMintOperation = 0x0000000c
    case nftTransferOperation = 0x0000000d
    
    // Credentials
    case nftCredential = 0x0000000e
    
    // Transactions
    case createAssetTransaction = 0x00000001
    case operationTransaction = 0x00000002
    case importTransaction = 0x00000003
    case exportTransaction = 0x00000004
}
