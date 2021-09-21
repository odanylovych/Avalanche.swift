//
//  GenesisAsset.swift
//  
//
//  Created by Ostap Danylovych on 31.08.2021.
//

import Foundation

public struct GenesisAsset: Equatable {
    public let alias: String
    public let networkID: NetworkID
    public let blockchainID: BlockchainID
    public let outputs: [TransferableOutput]
    public let inputs: [TransferableInput]
    public let memo: Data
    public let name: String
    public let symbol: String
    public let denomination: UInt8
    public let initialStates: [InitialState]
    
    public init(
        alias: String,
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
        guard memo.count <= 256 else {
            throw MalformedTransactionError.outOfRange(
                memo,
                expected: 0...256,
                name: "Memo length"
            )
        }
        guard name.count <= 128 else {
            throw MalformedTransactionError.outOfRange(
                name,
                expected: 0...128,
                name: "Name length"
            )
        }
        guard name.data(using: .ascii) != nil else {
            throw MalformedTransactionError.wrongValue(
                name,
                name: "Name",
                message: "The name must consist of only printable ASCII characters"
            )
        }
        guard symbol.count <= 4 else {
            throw MalformedTransactionError.outOfRange(
                symbol,
                expected: 0...4,
                name: "Symbol length"
            )
        }
        guard symbol.data(using: .ascii) != nil else {
            throw MalformedTransactionError.wrongValue(
                symbol,
                name: "Symbol",
                message: "The symbol must consist of only printable ASCII characters"
            )
        }
        guard denomination <= 32 else {
            throw MalformedTransactionError.outOfRange(
                denomination,
                expected: 0...32,
                name: "Denomination"
            )
        }
        self.alias = alias
        self.networkID = networkID
        self.blockchainID = blockchainID
        self.outputs = outputs
        self.inputs = inputs
        self.memo = memo
        self.name = name
        self.symbol = symbol
        self.denomination = denomination
        self.initialStates = initialStates
    }
}

extension GenesisAsset: AvalancheCodable {
    public init(from decoder: AvalancheDecoder) throws {
        try self.init(
            alias: try decoder.decode(),
            networkID: try decoder.decode(),
            blockchainID: try decoder.decode(),
            outputs: try decoder.decode(),
            inputs: try decoder.decode(),
            memo: try decoder.decode(),
            name: try decoder.decode(),
            symbol: try decoder.decode(),
            denomination: try decoder.decode(),
            initialStates: try decoder.decode()
        )
    }
    
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(alias, name: "alias")
            .encode(networkID, name: "networkID")
            .encode(blockchainID, name: "blockchainID")
            .encode(outputs, name: "outputs")
            .encode(inputs, name: "inputs")
            .encode(memo, name: "memo")
            .encode(name, name: "name")
            .encode(symbol, name: "symbol")
            .encode(denomination, name: "denomination")
            .encode(initialStates, name: "initialStates")
    }
}
