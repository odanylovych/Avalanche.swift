//
//  PChainTypeID.swift
//  
//
//  Created by Ostap Danylovych on 01.09.2021.
//

import Foundation

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
