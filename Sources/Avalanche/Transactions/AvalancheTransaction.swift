//
//  AvalancheTransaction.swift
//  
//
//  Created by Ostap Danylovych on 30.08.2021.
//

import Foundation

public class UnsignedAvalancheTransaction: AvalancheEncodable {
    public class var typeID: TypeID { fatalError("Not supported") }
    
    public func encode(in encoder: AvalancheEncoder) throws {
        fatalError("Not supported")
    }
}

public struct SignedAvalancheTransaction {
    public static let codecID: CodecID = .latest

    public let unsignedTransaction: UnsignedAvalancheTransaction
    public let credentials: [Credential]

    public init(unsignedTransaction: UnsignedAvalancheTransaction, credentials: [Credential]) {
        self.unsignedTransaction = unsignedTransaction
        self.credentials = credentials
    }
}

extension SignedAvalancheTransaction: SignedTransaction {
    public func serialized() throws -> Data {
        try AEncoder().encode(self).output
    }
}

extension SignedAvalancheTransaction: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.codecID)
            .encode(unsignedTransaction)
            .encode(credentials)
    }
}

public struct BlockchainID: ID {
    public static let size = 32
    
    public let raw: Data
    
    public init(raw: Data) {
        self.raw = raw
    }
}

public class BaseTransaction: UnsignedAvalancheTransaction {
    override public class var typeID: TypeID { CommonTypeID.baseTransaction }
    
    public let networkID: NetworkID
    public let blockchainID: BlockchainID
    public let outputs: [TransferableOutput]
    public let inputs: [TransferableInput]
    public let memo: Data
    
    public init(
        networkID: NetworkID,
        blockchainID: BlockchainID,
        outputs: [TransferableOutput],
        inputs: [TransferableInput],
        memo: Data
    ) throws {
        guard memo.count <= 256 else {
            throw MalformedTransactionError.outOfRange(
                memo,
                expected: 0...256,
                name: "Memo length"
            )
        }
        self.networkID = networkID
        self.blockchainID = blockchainID
        self.outputs = outputs
        self.inputs = inputs
        self.memo = memo
    }
    
    override public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.typeID)
            .encode(networkID)
            .encode(blockchainID)
            .encode(outputs)
            .encode(inputs)
            .encode(memo)
    }
}
