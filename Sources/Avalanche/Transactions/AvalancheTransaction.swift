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

public class CreateAssetTransaction: BaseTransaction {
    override public class var typeID: TypeID { CommonTypeID.createAssetTransaction }
    
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
    override public class var typeID: TypeID { CommonTypeID.operationTransaction }
    
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

// P-Chain

public struct NodeID: ID {
    public static let size = 20
    
    public let raw: Data
    
    public init(raw: Data) {
        self.raw = raw
    }
}

public struct Validator {
    public let nodeID: NodeID
    public let startTime: Date
    public let endTime: Date
    public let weight: UInt64
    
    public init(nodeID: NodeID, startTime: Date, endTime: Date, weight: UInt64) {
        self.nodeID = nodeID
        self.startTime = startTime
        self.endTime = endTime
        self.weight = weight
    }
}

extension Validator: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(nodeID)
            .encode(startTime)
            .encode(endTime)
            .encode(weight)
    }
}

public struct Stake {
    public let lockedOuts: [TransferableOutput]
    
    public init(lockedOuts: [TransferableOutput]) {
        self.lockedOuts = lockedOuts
    }
}

extension Stake: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(lockedOuts)
    }
}

public class AddValidatorTransaction: BaseTransaction {
    override public class var typeID: TypeID { PChainTypeID.addValidatorTransaction }
    
    public let validator: Validator
    public let stake: Stake
    public let rewardsOwner: SECP256K1OutputOwners
    public let shares: UInt32
    
    public init(
        networkID: NetworkID,
        blockchainID: BlockchainID,
        outputs: [TransferableOutput],
        inputs: [TransferableInput],
        memo: Data,
        validator: Validator,
        stake: Stake,
        rewardsOwner: SECP256K1OutputOwners,
        shares: UInt32
    ) throws {
        self.validator = validator
        self.stake = stake
        self.rewardsOwner = rewardsOwner
        self.shares = shares
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
        try encoder.encode(validator)
            .encode(stake)
            .encode(rewardsOwner)
            .encode(shares)
    }
}

public struct SubnetID: ID {
    public static let size = 32
    
    public let raw: Data
    
    public init(raw: Data) {
        self.raw = raw
    }
}

public struct SubnetAuth {
    public static let typeID: TypeID = PChainTypeID.subnetAuth
    
    public let signatureIndices: [UInt32]
    
    public init(signatureIndices: [UInt32]) {
        self.signatureIndices = signatureIndices
    }
}

extension SubnetAuth: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.typeID).encode(signatureIndices)
    }
}

public class AddSubnetValidatorTransaction: BaseTransaction {
    override public class var typeID: TypeID { PChainTypeID.addSubnetValidatorTransaction }
    
    public let validator: Validator
    public let subnetID: SubnetID
    public let subnetAuth: SubnetAuth
    
    public init(
        networkID: NetworkID,
        blockchainID: BlockchainID,
        outputs: [TransferableOutput],
        inputs: [TransferableInput],
        memo: Data,
        validator: Validator,
        subnetID: SubnetID,
        subnetAuth: SubnetAuth
    ) throws {
        self.validator = validator
        self.subnetID = subnetID
        self.subnetAuth = subnetAuth
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
        try encoder.encode(validator)
            .encode(subnetID)
            .encode(subnetAuth)
    }
}

public class AddDelegatorTransaction: BaseTransaction {
    override public class var typeID: TypeID { PChainTypeID.addDelegatorTransaction }
    
    public let validator: Validator
    public let stake: Stake
    public let rewardsOwner: SECP256K1OutputOwners
    
    public init(
        networkID: NetworkID,
        blockchainID: BlockchainID,
        outputs: [TransferableOutput],
        inputs: [TransferableInput],
        memo: Data,
        validator: Validator,
        stake: Stake,
        rewardsOwner: SECP256K1OutputOwners
    ) throws {
        self.validator = validator
        self.stake = stake
        self.rewardsOwner = rewardsOwner
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
        try encoder.encode(validator)
            .encode(stake)
            .encode(rewardsOwner)
    }
}

public class CreateSubnetTransaction: BaseTransaction {
    override public class var typeID: TypeID { PChainTypeID.createSubnetTransaction }
    
    public let rewardsOwner: SECP256K1OutputOwners
    
    public init(
        networkID: NetworkID,
        blockchainID: BlockchainID,
        outputs: [TransferableOutput],
        inputs: [TransferableInput],
        memo: Data,
        rewardsOwner: SECP256K1OutputOwners
    ) throws {
        self.rewardsOwner = rewardsOwner
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
        try encoder.encode(rewardsOwner)
    }
}

public class PChainImportTransaction: ImportTransaction {
    override public class var typeID: TypeID { PChainTypeID.importTransaction }
}

public class PChainExportTransaction: ExportTransaction {
    override public class var typeID: TypeID { PChainTypeID.exportTransaction }
}
