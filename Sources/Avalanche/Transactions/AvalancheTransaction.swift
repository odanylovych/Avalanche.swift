//
//  AvalancheTransaction.swift
//  
//
//  Created by Ostap Danylovych on 30.08.2021.
//

import Foundation

public class UnsignedAvalancheTransaction: UnsignedTransaction, AvalancheCodable {
    public typealias Addr = Address
    public typealias Signed = SignedAvalancheTransaction
    
    public class var typeID: TypeID { fatalError("Not supported") }
    
    public init() {}
    
    required public init(from decoder: AvalancheDecoder) throws {
        fatalError("Not supported")
    }
    
    public func utxoAddressIndices() -> [(Credential.Type, TransactionID, utxoIndex: UInt32, addressIndices: [UInt32])] {
        fatalError("Not supported")
    }
    
    public func toSigned(signatures: Dictionary<Address, Signature>) throws -> SignedAvalancheTransaction {
        fatalError("Not supported")
    }
    
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

extension SignedAvalancheTransaction: AvalancheCodable {
    public init(from decoder: AvalancheDecoder) throws {
        self.init(
            unsignedTransaction: try UnsignedAvalancheTransaction(from: decoder),
            credentials: try [Credential](from: decoder)
        )
    }
    
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.codecID, name: "codecID")
            .encode(unsignedTransaction, name: "unsignedTransaction")
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
        try AEncoder().encode(transaction).output
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
        super.init()
    }
    
    convenience required public init(from decoder: AvalancheDecoder) throws {
        try self.init(
            networkID: try NetworkID(from: decoder),
            blockchainID: try BlockchainID(from: decoder),
            outputs: try [TransferableOutput](from: decoder),
            inputs: try [TransferableInput](from: decoder),
            memo: try Data(from: decoder)
        )
    }

    override public func utxoAddressIndices() -> [
        (Credential.Type, TransactionID, utxoIndex: UInt32, addressIndices: [UInt32])
    ] {
        inputs.map { ($0.input.credentialType(), $0.transactionID, $0.utxoIndex, $0.input.addressIndices) }
    }
    
    override public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.typeID, name: "typeID")
            .encode(networkID, name: "networkID")
            .encode(blockchainID, name: "blockchainID")
            .encode(outputs, name: "outputs")
            .encode(inputs, name: "inputs")
            .encode(memo, name: "memo")
    }
}
