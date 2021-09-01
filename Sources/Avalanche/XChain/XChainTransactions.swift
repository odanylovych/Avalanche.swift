//
//  XChainTransactions.swift
//  
//
//  Created by Ostap Danylovych on 01.09.2021.
//

import Foundation

public class CreateAssetTransaction: BaseTransaction {
    override public class var typeID: TypeID { XChainTypeID.createAssetTransaction }
    
    public let name: String
    public let symbol: String
    public let denomination: UInt8
    public let initialStates: [InitialState]
    
    public init(
        networkID: NetworkID,
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
    override public class var typeID: TypeID { XChainTypeID.operationTransaction }
    
    public let operations: [TransferableOperation]
    
    public init(
        networkID: NetworkID,
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
    override public class var typeID: TypeID { XChainTypeID.importTransaction }
    
    public let sourceChain: BlockchainID
    public let transferableInputs: [TransferableInput]
    
    public init(
        networkID: NetworkID,
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
    override public class var typeID: TypeID { XChainTypeID.exportTransaction }
    
    public let destinationChain: BlockchainID
    public let transferableOutputs: [TransferableOutput]
    
    public init(
        networkID: NetworkID,
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
