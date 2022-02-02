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
    
    public func utxoAddressIndices() -> [(Credential.Type, TransactionID, utxoIndex: UInt32, addressIndices: [UInt32])] {
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
    public let pathes: Dictionary<Addr, Bip32Path>
    public let utxoAddresses: [(Credential.Type, [Addr])]
    
    public init(transaction: UnsignedAvalancheTransaction, utxos: [UTXO], pathes: Dictionary<Addr, Bip32Path>) throws {
        self.transaction = transaction
        self.pathes = pathes
        utxoAddresses = try transaction.utxoAddressIndices().map { credentialType, transactionID, utxoIndex, addressIndices in
            guard let utxo = utxos.first(where: { $0.transactionID == transactionID && $0.utxoIndex == utxoIndex }) else {
                throw ExtendedAvalancheTransactionError.noSuchUtxo(transactionID, utxoIndex: utxoIndex, in: utxos)
            }
            return (credentialType, addressIndices.map { utxo.output.addresses[Int($0)] })
        }
    }
    
    public func toSigned(signatures: Dictionary<Addr, Signature>) throws -> SignedAvalancheTransaction {
        return SignedAvalancheTransaction(
            unsignedTransaction: transaction,
            credentials: try utxoAddresses.map { credentialType, addresses in
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
        try Set(utxoAddresses.flatMap { $0.1 }).map { address in
            guard let path = pathes[address] else {
                throw ExtendedAvalancheTransactionError.noSuchPath(address, in: pathes)
            }
            return try address.extended(path: path)
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
        self.outputs = outputs
        self.inputs = inputs
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
    
    override public func utxoAddressIndices() -> [
        (Credential.Type, TransactionID, utxoIndex: UInt32, addressIndices: [UInt32])
    ] {
        inputs.map { ($0.input.credentialType(), $0.transactionID, $0.utxoIndex, $0.input.addressIndices) }
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
