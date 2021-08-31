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
    
    public let networkID: UInt32
    public let blockchainID: BlockchainID
    public let outputs: [TransferableOutput]
    public let inputs: [TransferableInput]
    public let memo: Data
    
    public init(
        networkID: UInt32,
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

public class CreateAssetTransaction: BaseTransaction {
    override public class var typeID: TypeID { CommonTypeID.createAssetTransaction }
    
    public let name: String
    public let symbol: String
    public let denomination: UInt8
    public let initialStates: [InitialState]
    
    public init(
        networkID: UInt32,
        blockchainID: BlockchainID,
        outputs: [TransferableOutput],
        inputs: [TransferableInput],
        memo: Data,
        name: String,
        symbol: String,
        denomination: UInt8,
        initialStates: [InitialState]
    ) throws {
        self.name = name
        self.symbol = symbol
        self.denomination = denomination
        self.initialStates = initialStates
        try super.init(
            networkID: networkID,
            blockchainID: blockchainID,
            outputs: outputs,
            inputs: inputs,
            memo: memo
        )
    }
    
    override public func encode(in encoder: AvalancheEncoder) throws {
        try super.encode(in: encoder)
        try encoder.encode(name)
            .encode(symbol)
            .encode(denomination)
            .encode(initialStates)
    }
}

public class OperationTransaction: BaseTransaction {
    override public class var typeID: TypeID { CommonTypeID.operationTransaction }
    
    public let operations: [TransferableOperation]
    
    public init(
        networkID: UInt32,
        blockchainID: BlockchainID,
        outputs: [TransferableOutput],
        inputs: [TransferableInput],
        memo: Data,
        operations: [TransferableOperation]
    ) throws {
        self.operations = operations
        try super.init(
            networkID: networkID,
            blockchainID: blockchainID,
            outputs: outputs,
            inputs: inputs,
            memo: memo
        )
    }
    
    override public func encode(in encoder: AvalancheEncoder) throws {
        try super.encode(in: encoder)
        try encoder.encode(operations)
    }
}

public class ImportTransaction: BaseTransaction {
    override public class var typeID: TypeID { CommonTypeID.importTransaction }
    
    public let sourceChain: BlockchainID
    public let transferableInputs: [TransferableInput]
    
    public init(
        networkID: UInt32,
        blockchainID: BlockchainID,
        outputs: [TransferableOutput],
        inputs: [TransferableInput],
        memo: Data,
        sourceChain: BlockchainID,
        transferableInputs: [TransferableInput]
    ) throws {
        self.sourceChain = sourceChain
        self.transferableInputs = transferableInputs
        try super.init(
            networkID: networkID,
            blockchainID: blockchainID,
            outputs: outputs,
            inputs: inputs,
            memo: memo
        )
    }
    
    override public func encode(in encoder: AvalancheEncoder) throws {
        try super.encode(in: encoder)
        try encoder.encode(sourceChain).encode(transferableInputs)
    }
}

public class ExportTransaction: BaseTransaction {
    override public class var typeID: TypeID { CommonTypeID.exportTransaction }
    
    public let destinationChain: BlockchainID
    public let transferableOutputs: [TransferableOutput]
    
    public init(
        networkID: UInt32,
        blockchainID: BlockchainID,
        outputs: [TransferableOutput],
        inputs: [TransferableInput],
        memo: Data,
        destinationChain: BlockchainID,
        transferableOutputs: [TransferableOutput]
    ) throws {
        self.destinationChain = destinationChain
        self.transferableOutputs = transferableOutputs
        try super.init(
            networkID: networkID,
            blockchainID: blockchainID,
            outputs: outputs,
            inputs: inputs,
            memo: memo
        )
    }
    
    override public func encode(in encoder: AvalancheEncoder) throws {
        try super.encode(in: encoder)
        try encoder.encode(destinationChain).encode(transferableOutputs)
    }
}
