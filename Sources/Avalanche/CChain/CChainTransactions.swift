//
//  CChainTransactions.swift
//  
//
//  Created by Ostap Danylovych on 01.09.2021.
//

import Foundation

public class CChainExportTransaction: UnsignedAvalancheTransaction, AvalancheDecodable {
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
        self.exportedOutputs = exportedOutputs.sorted()
        super.init()
    }
    
    convenience required public init(dynamic decoder: AvalancheDecoder, typeID: UInt32) throws {
        guard typeID == Self.typeID.rawValue else {
            throw AvalancheDecoderError.dataCorrupted(
                typeID,
                AvalancheDecoderError.Context(path: decoder.path, description: "Wrong typeID")
            )
        }
        self.init(
            networkID: try decoder.decode(name: "networkID"),
            blockchainID: try decoder.decode(name: "blockchainID"),
            destinationChain: try decoder.decode(name: "destinationChain"),
            inputs: try decoder.decode(name: "inputs"),
            exportedOutputs: try decoder.decode(name: "exportedOutputs")
        )
    }
    
    override public var inputsData: [InputData] {
        []
    }
    
    override public var allOutputs: [TransferableOutput] {
        exportedOutputs
    }
    
    override public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.codecID, name: "codecID")
            .encode(Self.typeID, name: "typeID")
            .encode(networkID, name: "networkID")
            .encode(blockchainID, name: "blockchainID")
            .encode(destinationChain, name: "destinationChain")
            .encode(inputs, name: "inputs")
            .encode(exportedOutputs, name: "exportedOutputs")
    }
    
    override public func equalTo(rhs: UnsignedAvalancheTransaction) -> Bool {
        guard let rhs = rhs as? Self else { return false }
        return networkID == rhs.networkID
            && blockchainID == rhs.blockchainID
            && destinationChain == rhs.destinationChain
            && inputs == rhs.inputs
            && exportedOutputs == rhs.exportedOutputs
    }
}

public class CChainImportTransaction: UnsignedAvalancheTransaction, AvalancheDecodable {
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
        self.importedInputs = importedInputs.sorted()
        self.outputs = outputs
        super.init()
    }
    
    convenience required public init(dynamic decoder: AvalancheDecoder, typeID: UInt32) throws {
        guard typeID == Self.typeID.rawValue else {
            throw AvalancheDecoderError.dataCorrupted(
                typeID,
                AvalancheDecoderError.Context(path: decoder.path, description: "Wrong typeID")
            )
        }
        self.init(
            networkID: try decoder.decode(name: "networkID"),
            blockchainID: try decoder.decode(name: "blockchainID"),
            sourceChain: try decoder.decode(name: "sourceChain"),
            importedInputs: try decoder.decode(name: "importedInputs"),
            outputs: try decoder.decode(name: "outputs")
        )
    }
    
    override public var inputsData: [InputData] {
        importedInputs.map { InputData(
            credentialType: $0.input.credentialType(),
            transactionID: $0.transactionID,
            utxoIndex: $0.utxoIndex,
            addressIndices: $0.input.addressIndices
        ) }
    }
    
    override public var allOutputs: [TransferableOutput] {
        []
    }
    
    override public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.codecID, name: "codecID")
            .encode(Self.typeID, name: "typeID")
            .encode(networkID, name: "networkID")
            .encode(blockchainID, name: "blockchainID")
            .encode(sourceChain, name: "sourceChain")
            .encode(importedInputs, name: "importedInputs")
            .encode(outputs, name: "outputs")
    }
    
    override public func equalTo(rhs: UnsignedAvalancheTransaction) -> Bool {
        guard let rhs = rhs as? Self else { return false }
        return networkID == rhs.networkID
            && blockchainID == rhs.blockchainID
            && sourceChain == rhs.sourceChain
            && importedInputs == rhs.importedInputs
            && outputs == rhs.outputs
    }
}
