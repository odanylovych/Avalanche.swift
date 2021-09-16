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
        super.init()
    }
    
    convenience required public init(from decoder: AvalancheDecoder) throws {
        self.init(
            networkID: try NetworkID(from: decoder),
            blockchainID: try BlockchainID(from: decoder),
            destinationChain: try BlockchainID(from: decoder),
            inputs: try [EVMInput](from: decoder),
            exportedOutputs: try [TransferableOutput](from: decoder)
        )
    }

    override public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.typeID, name: "typeID")
            .encode(networkID, name: "networkID")
            .encode(blockchainID, name: "blockchainID")
            .encode(destinationChain, name: "destinationChain")
            .encode(inputs, name: "inputs")
            .encode(exportedOutputs, name: "exportedOutputs")
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
        super.init()
    }
    
    convenience required public init(from decoder: AvalancheDecoder) throws {
        self.init(
            networkID: try NetworkID(from: decoder),
            blockchainID: try BlockchainID(from: decoder),
            sourceChain: try BlockchainID(from: decoder),
            importedInputs: try [TransferableInput](from: decoder),
            outputs: try [EVMOutput](from: decoder)
        )
    }

    override public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.typeID, name: "typeID")
            .encode(networkID, name: "networkID")
            .encode(blockchainID, name: "blockchainID")
            .encode(sourceChain, name: "sourceChain")
            .encode(importedInputs, name: "importedInputs")
            .encode(outputs, name: "outputs")
    }
}
