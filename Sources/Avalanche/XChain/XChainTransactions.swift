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
    
    convenience required public init(dynamic decoder: AvalancheDecoder, typeID: UInt32) throws {
        guard typeID == Self.typeID.rawValue else {
            throw AvalancheDecoderError.dataCorrupted(
                typeID,
                AvalancheDecoderError.Context(path: decoder.path, description: "Wrong typeID")
            )
        }
        try self.init(
            networkID: try decoder.decode(name: "networkID"),
            blockchainID: try decoder.decode(name: "blockchainID"),
            outputs: try decoder.decode(name: "outputs"),
            inputs: try decoder.decode(name: "inputs"),
            memo: try decoder.decode(name: "memo"),
            name: try decoder.decode(name: "name"),
            symbol: try decoder.decode(name: "symbol"),
            denomination: try decoder.decode(name: "denomination"),
            initialStates: try decoder.decode(name: "initialStates")
        )
    }
    
    override public func encode(in encoder: AvalancheEncoder) throws {
        try super.encode(in: encoder)
        try encoder.encode(name, name: "name")
            .encode(symbol, name: "symbol")
            .encode(denomination, name: "denomination")
            .encode(initialStates, name: "initialStates")
    }
    
    override public func equalTo(rhs: UnsignedAvalancheTransaction) -> Bool {
        guard let rhs = rhs as? Self else { return false }
        return name == rhs.name
            && symbol == rhs.symbol
            && denomination == rhs.denomination
            && initialStates == rhs.initialStates
            && super.equalTo(rhs: rhs)
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
    
    convenience required public init(dynamic decoder: AvalancheDecoder, typeID: UInt32) throws {
        guard typeID == Self.typeID.rawValue else {
            throw AvalancheDecoderError.dataCorrupted(
                typeID,
                AvalancheDecoderError.Context(path: decoder.path, description: "Wrong typeID")
            )
        }
        try self.init(
            networkID: try decoder.decode(name: "networkID"),
            blockchainID: try decoder.decode(name: "blockchainID"),
            outputs: try decoder.decode(name: "outputs"),
            inputs: try decoder.decode(name: "inputs"),
            memo: try decoder.decode(name: "memo"),
            operations: try decoder.decode(name: "operations")
        )
    }
    
    override public func encode(in encoder: AvalancheEncoder) throws {
        try super.encode(in: encoder)
        try encoder.encode(operations, name: "operations")
    }
    
    override public func equalTo(rhs: UnsignedAvalancheTransaction) -> Bool {
        guard let rhs = rhs as? Self else { return false }
        return operations == rhs.operations
            && super.equalTo(rhs: rhs)
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
    
    convenience required public init(dynamic decoder: AvalancheDecoder, typeID: UInt32) throws {
        guard typeID == Self.typeID.rawValue else {
            throw AvalancheDecoderError.dataCorrupted(
                typeID,
                AvalancheDecoderError.Context(path: decoder.path, description: "Wrong typeID")
            )
        }
        try self.init(
            networkID: try decoder.decode(name: "networkID"),
            blockchainID: try decoder.decode(name: "blockchainID"),
            outputs: try decoder.decode(name: "outputs"),
            inputs: try decoder.decode(name: "inputs"),
            memo: try decoder.decode(name: "memo"),
            sourceChain: try decoder.decode(name: "sourceChain"),
            transferableInputs: try decoder.decode(name: "transferableInputs")
        )
    }
    
    override public func encode(in encoder: AvalancheEncoder) throws {
        try super.encode(in: encoder)
        try encoder.encode(sourceChain, name: "sourceChain")
            .encode(transferableInputs, name: "transferableInputs")
    }
    
    override public func equalTo(rhs: UnsignedAvalancheTransaction) -> Bool {
        guard let rhs = rhs as? Self else { return false }
        return sourceChain == rhs.sourceChain
            && transferableInputs == rhs.transferableInputs
            && super.equalTo(rhs: rhs)
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
    
    convenience required public init(dynamic decoder: AvalancheDecoder, typeID: UInt32) throws {
        guard typeID == Self.typeID.rawValue else {
            throw AvalancheDecoderError.dataCorrupted(
                typeID,
                AvalancheDecoderError.Context(path: decoder.path, description: "Wrong typeID")
            )
        }
        try self.init(
            networkID: try decoder.decode(name: "networkID"),
            blockchainID: try decoder.decode(name: "blockchainID"),
            outputs: try decoder.decode(name: "outputs"),
            inputs: try decoder.decode(name: "inputs"),
            memo: try decoder.decode(name: "memo"),
            destinationChain: try decoder.decode(name: "destinationChain"),
            transferableOutputs: try decoder.decode(name: "transferableOutputs")
        )
    }
    
    override public func encode(in encoder: AvalancheEncoder) throws {
        try super.encode(in: encoder)
        try encoder.encode(destinationChain, name: "destinationChain")
            .encode(transferableOutputs, name: "transferableOutputs")
    }
    
    override public func equalTo(rhs: UnsignedAvalancheTransaction) -> Bool {
        guard let rhs = rhs as? Self else { return false }
        return destinationChain == rhs.destinationChain
            && transferableOutputs == rhs.transferableOutputs
            && super.equalTo(rhs: rhs)
    }
}
