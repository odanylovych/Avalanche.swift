//
//  AvalancheTransaction.swift
//  
//
//  Created by Ostap Danylovych on 30.08.2021.
//

import Foundation

public class UnsignedAvalancheTransaction: UnsignedTransaction, AvalancheEncodable {
    public typealias Addr = Address
    public typealias Signed = SignedAvalancheTransaction
    
    public class var typeID: TypeID { fatalError("Not supported") }
    
    public func utxoAddressIndices() -> [(TransactionID, UInt32, [UInt32])] {
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

extension SignedAvalancheTransaction: AvalancheEncodable {
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
    public let utxoAddresses: [[Addr]]
    
    public init(transaction: UnsignedAvalancheTransaction, utxos: [UTXO], pathes: Dictionary<Addr, Bip32Path>) {
        self.transaction = transaction
        self.pathes = pathes
        utxoAddresses = transaction.utxoAddressIndices().map { transactionID, utxoIndex, addressIndices in
            let utxo = utxos.first(where: { $0.transactionId == transactionID && $0.utxoIndex == utxoIndex })!
            return addressIndices.map { utxo.output.addresses[Int($0)] }
        }
    }
    
    public func toSigned(signatures: Dictionary<Addr, Signature>) throws -> SignedAvalancheTransaction {
        return SignedAvalancheTransaction(
            unsignedTransaction: transaction,
            credentials: utxoAddresses.map { addresses in
                SECP256K1Credential(signatures: addresses.map { signatures[$0]! })
            }
        )
    }
    
    public func serialized() throws -> Data {
        try AEncoder().encode(transaction).output
    }
    
    public func signingAddresses() throws -> [Addr.Extended] {
        try Set(utxoAddresses.flatMap { $0 }).map { try $0.extended(path: pathes[$0]!) }
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
    
    override public func utxoAddressIndices() -> [(TransactionID, UInt32, [UInt32])] {
        inputs.map { ($0.transactionID, $0.utxoIndex, ($0.input as! SECP256K1TransferInput).addressIndices)}
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
