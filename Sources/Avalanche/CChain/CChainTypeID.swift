//
//  CChainTypeID.swift
//  
//
//  Created by Ostap Danylovych on 02.09.2021.
//

import Foundation

public enum CChainTypeID: UInt32, TypeID, CaseIterable {
    // Inputs
    case secp256K1TransferInput = 0x00000005
    
    // Outputs
    case secp256K1TransferOutput = 0x00000007
    
    // Credentials
    case secp256K1Credential = 0x00000009
    
    // Transactions
    case exportTransaction = 0x00000001
    case importTransaction = 0x00000000
}

public struct CChainDynamicTypeRegistry: DynamicTypeRegistry {
    public typealias TID = CChainTypeID
    
    public let inputs: [TID: (AvalancheDecoder, UInt32) throws -> Input]
    public let outputs: [TID: (AvalancheDecoder, UInt32) throws -> Output]
    public let operations: [TID: (AvalancheDecoder, UInt32) throws -> Operation]
    public let credentials: [TID: (AvalancheDecoder, UInt32) throws -> Credential]
    public let transactions: [TID: (AvalancheDecoder, UInt32) throws -> UnsignedAvalancheTransaction]
    
    private init() {
        inputs = [.secp256K1TransferInput: Self.wrap(SECP256K1TransferInput.self)]
        outputs = [.secp256K1TransferOutput: Self.wrap(SECP256K1TransferOutput.self)]
        operations = [:]
        credentials = [.secp256K1Credential: Self.wrap(SECP256K1Credential.self)]
        transactions = [
            .exportTransaction: Self.wrap(CChainExportTransaction.self),
            .importTransaction: Self.wrap(CChainImportTransaction.self),
        ]
    }
    
    public static var instance = Self()
}
