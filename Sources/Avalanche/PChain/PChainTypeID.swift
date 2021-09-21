//
//  PChainTypeID.swift
//  
//
//  Created by Ostap Danylovych on 01.09.2021.
//

import Foundation

public enum PChainTypeID: UInt32, TypeID, CaseIterable {
    // Inputs
    case secp256K1TransferInput = 0x00000005
    
    // Outputs
    case secp256K1TransferOutput = 0x00000007
    case secp256K1OutputOwners = 0x0000000b
    
    // Credentials
    case secp256K1Credential = 0x00000009
    
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

public struct PChainDynamicTypeRegistry: DynamicTypeRegistry {
    public typealias TID = PChainTypeID
    
    public let inputs: [TID: (AvalancheDecoder, UInt32) throws -> Input]
    public let outputs: [TID: (AvalancheDecoder, UInt32) throws -> Output]
    public let operations: [TID: (AvalancheDecoder, UInt32) throws -> Operation]
    public let credentials: [TID: (AvalancheDecoder, UInt32) throws -> Credential]
    public let transactions: [TID: (AvalancheDecoder, UInt32) throws -> UnsignedAvalancheTransaction]
    
    private init() {
        inputs = [.secp256K1TransferInput: Self.wrap(SECP256K1TransferInput.self)]
        outputs = [
            .secp256K1TransferOutput: Self.wrap(SECP256K1TransferOutput.self),
            .secp256K1OutputOwners: Self.wrap(SECP256K1OutputOwners.self),
        ]
        operations = [:]
        credentials = [.secp256K1Credential: Self.wrap(SECP256K1Credential.self)]
        transactions = [
            .addValidatorTransaction: Self.wrap(AddValidatorTransaction.self),
            .addSubnetValidatorTransaction: Self.wrap(AddSubnetValidatorTransaction.self),
            .addDelegatorTransaction: Self.wrap(AddDelegatorTransaction.self),
            .createSubnetTransaction: Self.wrap(CreateSubnetTransaction.self),
            .importTransaction: Self.wrap(PChainImportTransaction.self),
            .exportTransaction: Self.wrap(PChainExportTransaction.self),
        ]
    }
    
    public static var instance = Self()
}
