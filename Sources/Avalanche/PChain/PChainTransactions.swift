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

extension Validator: AvalancheCodable {
    public init(from decoder: AvalancheDecoder) throws {
        self.init(
            nodeID: try NodeID(from: decoder),
            startTime: try Date(from: decoder),
            endTime: try Date(from: decoder),
            weight: try UInt64(from: decoder)
        )
    }
    
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(nodeID, name: "nodeID")
            .encode(startTime, name: "startTime")
            .encode(endTime, name: "endTime")
            .encode(weight, name: "weight")
    }
}

public struct Stake {
    public let lockedOutputs: [TransferableOutput]
    
    public init(lockedOutputs: [TransferableOutput]) {
        self.lockedOutputs = lockedOutputs
    }
}

extension Stake: AvalancheCodable {
    public init(from decoder: AvalancheDecoder) throws {
        self.init(lockedOutputs: try [TransferableOutput](from: decoder))
    }
    
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(lockedOutputs, name: "lockedOutputs")
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
    
    convenience required public init(from decoder: AvalancheDecoder) throws {
        try self.init(
            networkID: try NetworkID(from: decoder),
            blockchainID: try BlockchainID(from: decoder),
            outputs: try [TransferableOutput](from: decoder),
            inputs: try [TransferableInput](from: decoder),
            memo: try Data(from: decoder),
            validator: try Validator(from: decoder),
            stake: try Stake(from: decoder),
            rewardsOwner: try SECP256K1OutputOwners(from: decoder),
            shares: try UInt32(from: decoder)
        )
    }

    override public func encode(in encoder: AvalancheEncoder) throws {
        try super.encode(in: encoder)
        try encoder.encode(validator, name: "validator")
            .encode(stake, name: "stake")
            .encode(rewardsOwner, name: "rewardsOwner")
            .encode(shares, name: "shares")
    }
}

public struct SubnetAuth {
    public static let typeID: TypeID = PChainTypeID.subnetAuth
    
    public let signatureIndices: [UInt32]
    
    public init(signatureIndices: [UInt32]) {
        self.signatureIndices = signatureIndices
    }
}

extension SubnetAuth: AvalancheCodable {
    public init(from decoder: AvalancheDecoder) throws {
        self.init(signatureIndices: try [UInt32](from: decoder))
    }
    
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.typeID, name: "typeID")
            .encode(signatureIndices, name: "signatureIndices")
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
    
    convenience required public init(from decoder: AvalancheDecoder) throws {
        try self.init(
            networkID: try NetworkID(from: decoder),
            blockchainID: try BlockchainID(from: decoder),
            outputs: try [TransferableOutput](from: decoder),
            inputs: try [TransferableInput](from: decoder),
            memo: try Data(from: decoder),
            validator: try Validator(from: decoder),
            subnetID: try BlockchainID(from: decoder),
            subnetAuth: try SubnetAuth(from: decoder)
        )
    }

    override public func encode(in encoder: AvalancheEncoder) throws {
        try super.encode(in: encoder)
        try encoder.encode(validator, name: "validator")
            .encode(subnetID, name: "subnetID")
            .encode(subnetAuth, name: "subnetAuth")
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
    
    convenience required public init(from decoder: AvalancheDecoder) throws {
        try self.init(
            networkID: try NetworkID(from: decoder),
            blockchainID: try BlockchainID(from: decoder),
            outputs: try [TransferableOutput](from: decoder),
            inputs: try [TransferableInput](from: decoder),
            memo: try Data(from: decoder),
            validator: try Validator(from: decoder),
            stake: try Stake(from: decoder),
            rewardsOwner: try SECP256K1OutputOwners(from: decoder)
        )
    }

    override public func encode(in encoder: AvalancheEncoder) throws {
        try super.encode(in: encoder)
        try encoder.encode(validator, name: "validator")
            .encode(stake, name: "stake")
            .encode(rewardsOwner, name: "rewardsOwner")
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
    
    convenience required public init(from decoder: AvalancheDecoder) throws {
        try self.init(
            networkID: try NetworkID(from: decoder),
            blockchainID: try BlockchainID(from: decoder),
            outputs: try [TransferableOutput](from: decoder),
            inputs: try [TransferableInput](from: decoder),
            memo: try Data(from: decoder),
            rewardsOwner: try SECP256K1OutputOwners(from: decoder)
        )
    }

    override public func encode(in encoder: AvalancheEncoder) throws {
        try super.encode(in: encoder)
        try encoder.encode(rewardsOwner, name: "rewardsOwner")
    }
}

public class PChainImportTransaction: ImportTransaction {
    override public class var typeID: TypeID { PChainTypeID.importTransaction }
}

public class PChainExportTransaction: ExportTransaction {
    override public class var typeID: TypeID { PChainTypeID.exportTransaction }
}
