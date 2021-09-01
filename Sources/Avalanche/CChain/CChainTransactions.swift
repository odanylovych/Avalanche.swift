//
//  CChainTransactions.swift
//  
//
//  Created by Ostap Danylovych on 01.09.2021.
//

import Foundation

public class CChainExportTransaction: UnsignedAvalancheTransaction {
    override public class var typeID: TypeID { CChainTypeID.exportTransaction }
    
    public let networkID: NetworkID
    public let blockchainID: BlockchainID
    public let destinationChain: BlockchainID
    public let inputs: [EVMInput]
    public let exportedOutputs: [TransferableOutput]
    
    public init(
        networkID: NetworkID,
        blockchainID: BlockchainID,
        destinationChain: BlockchainID,
        inputs: [EVMInput],
        exportedOutputs: [TransferableOutput]
    ) {
        self.networkID = networkID
        self.blockchainID = blockchainID
        self.destinationChain = destinationChain
        self.inputs = inputs
        self.exportedOutputs = exportedOutputs
    }
    
    override public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.typeID)
            .encode(networkID)
            .encode(blockchainID)
            .encode(destinationChain)
            .encode(inputs)
            .encode(exportedOutputs)
    }
}

public class CChainImportTransaction: UnsignedAvalancheTransaction {
    override public class var typeID: TypeID { CChainTypeID.importTransaction }
    
    public let networkID: NetworkID
    public let blockchainID: BlockchainID
    public let sourceChain: BlockchainID
    public let importedInputs: [TransferableInput]
    public let outputs: [EVMOutput]
    
    public init(
        networkID: NetworkID,
        blockchainID: BlockchainID,
        sourceChain: BlockchainID,
        importedInputs: [TransferableInput],
        outputs: [EVMOutput]
    ) {
        self.networkID = networkID
        self.blockchainID = blockchainID
        self.sourceChain = sourceChain
        self.importedInputs = importedInputs
        self.outputs = outputs
    }
    
    override public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.typeID)
            .encode(networkID)
            .encode(blockchainID)
            .encode(sourceChain)
            .encode(importedInputs)
            .encode(outputs)
    }
}
