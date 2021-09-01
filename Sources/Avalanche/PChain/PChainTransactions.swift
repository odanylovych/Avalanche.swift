//
//  PChainTransactions.swift
//  
//
//  Created by Ostap Danylovych on 01.09.2021.
//

import Foundation

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
    public let subnetID: BlockchainID
    public let subnetAuth: SubnetAuth
    
    public init(
        networkID: NetworkID,
        blockchainID: BlockchainID,
        outputs: [TransferableOutput],
        inputs: [TransferableInput],
        memo: Data,
        validator: Validator,
        subnetID: BlockchainID,
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
