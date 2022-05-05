//
//  AvalancheTransaction.swift
//  
//
//  Created by Ostap Danylovych on 30.08.2021.
//

import Foundation

public class UnsignedAvalancheTransaction: UnsignedTransaction, AvalancheEncodable, AvalancheDynamicDecodableTypeID, Equatable {
    public typealias Addr = Address
    public typealias Signed = SignedAvalancheTransaction
    
    public static let codecID: CodecID = .latest
    public class var typeID: TypeID { fatalError("Not supported") }
    
    public struct InputData {
        public let credentialType: Credential.Type
        public let transactionID: TransactionID
        public let utxoIndex: UInt32
        public let addressIndices: [UInt32]
    }
    
    public init() {}
    
    required public init(dynamic decoder: AvalancheDecoder, typeID: UInt32) throws {
        fatalError("Not supported")
    }
    
    public static func from(decoder: AvalancheDecoder) throws -> Self {
        let codecID: CodecID = try decoder.decode(name: "codecID")
        guard codecID == Self.codecID else {
            throw AvalancheDecoderError.dataCorrupted(
                codecID,
                AvalancheDecoderError.Context(path: decoder.path)
            )
        }
        return try decoder.context.dynamicParser.decode(transaction: decoder) as! Self
    }
    
    public var inputsData: [InputData] {
        fatalError("Not supported")
    }
    
    public var allOutputs: [TransferableOutput] {
        fatalError("Not supported")
    }
    
    public func encode(in encoder: AvalancheEncoder) throws {
        fatalError("Not supported")
    }
    
    public func equalTo(rhs: UnsignedAvalancheTransaction) -> Bool {
        fatalError("Not supported")
    }
    
    public static func == (lhs: UnsignedAvalancheTransaction, rhs: UnsignedAvalancheTransaction) -> Bool {
        lhs.equalTo(rhs: rhs)
    }
}

public struct SignedAvalancheTransaction: SignedTransaction, Equatable {
    public let unsignedTransaction: UnsignedAvalancheTransaction
    public let credentials: [Credential]

    public init(unsignedTransaction: UnsignedAvalancheTransaction, credentials: [Credential]) {
        self.unsignedTransaction = unsignedTransaction
        self.credentials = credentials
    }
}

extension SignedAvalancheTransaction: AvalancheCodable {
    public init(from decoder: AvalancheDecoder) throws {
        self.init(
            unsignedTransaction: try decoder.dynamic(name: "unsignedTransaction"),
            credentials: try decoder.dynamic(name: "credentials")
        )
    }
    
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(unsignedTransaction, name: "unsignedTransaction")
            .encode(credentials, name: "credentials")
    }
}

public struct ExtendedAvalancheTransaction: ExtendedUnsignedTransaction {
    public typealias Addr = Address
    public typealias Signed = SignedAvalancheTransaction
    
    public let transaction: UnsignedAvalancheTransaction
    public let credential: [(Credential.Type, [Addr])]
    public let extended: [Addr: Addr.Extended]
    
    public init(transaction: UnsignedAvalancheTransaction,
                credential: [(Credential.Type, [Addr])],
                extended: [Addr: Addr.Extended]) {
        self.transaction = transaction
        self.credential = credential
        self.extended = extended
    }
    
    public func toSigned(signatures: Dictionary<Addr, Signature>) throws -> SignedAvalancheTransaction {
        return SignedAvalancheTransaction(
            unsignedTransaction: transaction,
            credentials: try credential.map { credentialType, addresses in
                credentialType.init(signatures: try addresses.map { address in
                    guard let signature = signatures[address] else {
                        throw ExtendedAvalancheTransactionError.noSuchSignature(address, in: signatures)
                    }
                    return signature
                })
            }
        )
    }
    
    public func serialized() throws -> Data {
        try DefaultAvalancheEncoder().encode(transaction).output
    }
    
    public func signingAddresses() throws -> [Addr.Extended] {
        try Set(credential.flatMap { $0.1 }).map { address in
            guard let extended = extended[address] else {
                throw ExtendedAvalancheTransactionError.noSuchPath(address, in: extended)
            }
            return extended
        }
    }
}

public struct BlockchainID: ID {
    public static let size = 32
    
    public let raw: Data
    
    public init(raw: Data) {
        self.raw = raw
    }
}

public class BaseTransaction: UnsignedAvalancheTransaction, AvalancheDecodable {
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
        self.outputs = outputs.sorted()
        self.inputs = inputs.sorted()
        self.memo = memo
        super.init()
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
            memo: try decoder.decode(name: "memo")
        )
    }
    
    override public var inputsData: [InputData] {
        inputs.map { InputData(
            credentialType: $0.input.credentialType(),
            transactionID: $0.transactionID,
            utxoIndex: $0.utxoIndex,
            addressIndices: $0.input.addressIndices
        ) }
    }
    
    override public var allOutputs: [TransferableOutput] {
        outputs
    }
    
    override public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.codecID, name: "codecID")
            .encode(Self.typeID, name: "typeID")
            .encode(networkID, name: "networkID")
            .encode(blockchainID, name: "blockchainID")
            .encode(outputs, name: "outputs")
            .encode(inputs, name: "inputs")
            .encode(memo, name: "memo")
    }
    
    override public func equalTo(rhs: UnsignedAvalancheTransaction) -> Bool {
        guard let rhs = rhs as? Self else { return false }
        return networkID == rhs.networkID
            && blockchainID == rhs.blockchainID
            && outputs == rhs.outputs
            && inputs == rhs.inputs
            && memo == rhs.memo
    }
}
