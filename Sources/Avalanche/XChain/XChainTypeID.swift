//
//  XChainTypeID.swift
//  
//
//  Created by Ostap Danylovych on 01.09.2021.
//

import Foundation

public enum XChainTypeID: UInt32, TypeID, CaseIterable {
    // Inputs
    case secp256K1TransferInput = 0x00000005
    
    // Outputs
    case secp256K1TransferOutput = 0x00000007
    case secp256K1MintOutput = 0x00000006
    case nftTransferOutput = 0x0000000b
    case nftMintOutput = 0x0000000a
    
    // Operations
    case secp256K1MintOperation = 0x00000008
    case nftMintOperation = 0x0000000c
    case nftTransferOperation = 0x0000000d
    
    // Credentials
    case secp256K1Credential = 0x00000009
    case nftCredential = 0x0000000e
    
    // Transactions
    case baseTransaction = 0x00000000
    case createAssetTransaction = 0x00000001
    case operationTransaction = 0x00000002
    case importTransaction = 0x00000003
    case exportTransaction = 0x00000004
}

public struct XChainDynamicTypeRegistry: DynamicTypeRegistry {
    public typealias TID = XChainTypeID
    
    public let inputs: [TID: (AvalancheDecoder, UInt32) throws -> Input]
    public let outputs: [TID: (AvalancheDecoder, UInt32) throws -> Output]
    public let operations: [TID: (AvalancheDecoder, UInt32) throws -> Operation]
    public let credentials: [TID: (AvalancheDecoder, UInt32) throws -> Credential]
    public let transactions: [TID: (AvalancheDecoder, UInt32) throws -> UnsignedAvalancheTransaction]
    
    private init() {
        inputs = [.secp256K1TransferInput: Self.wrap(SECP256K1TransferInput.self)]
        outputs = [
            .secp256K1TransferOutput: Self.wrap(SECP256K1TransferOutput.self),
            .secp256K1MintOutput: Self.wrap(SECP256K1MintOutput.self),
            .nftTransferOutput: Self.wrap(NFTTransferOutput.self),
            .nftMintOutput: Self.wrap(NFTMintOutput.self),
        ]
        operations = [
            .secp256K1MintOperation: Self.wrap(SECP256K1MintOperation.self),
            .nftMintOperation: Self.wrap(NFTMintOperation.self),
            .nftTransferOperation: Self.wrap(NFTTransferOperation.self),
        ]
        credentials = [
            .secp256K1Credential: Self.wrap(SECP256K1Credential.self),
            .nftCredential: Self.wrap(NFTCredential.self),
        ]
        transactions = [
            .baseTransaction: Self.wrap(BaseTransaction.self),
            .createAssetTransaction: Self.wrap(CreateAssetTransaction.self),
            .operationTransaction: Self.wrap(OperationTransaction.self),
            .importTransaction: Self.wrap(ImportTransaction.self),
            .exportTransaction: Self.wrap(ExportTransaction.self),
        ]
    }
    
    public static var instance = Self()
}
