//
//  EthereumTransaction.swift
//  
//
//  Created by Ostap Danylovych on 27.01.2022.
//

import Foundation
#if !COCOAPODS
import BigInt
import web3swift
#endif

extension EthereumTransaction: UnsignedTransaction {
    public typealias Addr = EthereumAddress
    public typealias Signed = Self
    
    public func toSigned(signatures: Dictionary<EthereumAddress, Signature>) throws -> Self {
        guard let signature = signatures.first?.value else {
            throw EthereumTransactionError.noSignature
        }
        guard let chainID = intrinsicChainID else {
            throw EthereumTransactionError.emptyChainID
        }
        let v = signature.raw[64]
        let r = Data(signature.raw[0..<32])
        let s = Data(signature.raw[32..<64])
        var d = BigUInt(0)
        if v >= 0 && v <= 3 {
            d = BigUInt(35)
        } else if v >= 27 && v <= 30 {
            d = BigUInt(8)
        } else if v >= 31 && v <= 34 {
            d = BigUInt(4)
        }
        var transaction = self
        transaction.v = BigUInt(v) + d + chainID + chainID
        transaction.r = BigUInt(r)
        transaction.s = BigUInt(s)
        return transaction
    }
}

extension EthereumTransaction: SignedTransaction {
    public func serialized() throws -> Data {
        guard let data = encode() else {
            throw EthereumTransactionError.encodeError
        }
        return data
    }
}

public struct ExtendedEthereumTransaction: ExtendedUnsignedTransaction {
    public typealias Addr = EthereumAddress
    public typealias Signed = EthereumTransaction
    
    public let transaction: EthereumTransaction
    public let account: Addr.Extended
    
    public init(transaction: EthereumTransaction, account: Addr.Extended, chainID: BigUInt) {
        var transaction = transaction
        transaction.UNSAFE_setChainID(chainID)
        self.transaction = transaction
        self.account = account
    }
    
    public func serialized() throws -> Data {
        guard let data = transaction.encode(forSignature: true) else {
            throw EthereumTransactionError.encodeError
        }
        return data
    }
    
    public func toSigned(signatures: Dictionary<EthereumAddress, Signature>) throws -> EthereumTransaction {
        try transaction.toSigned(signatures: signatures)
    }
    
    public func signingAddresses() throws -> [Addr.Extended] {
        [account]
    }
}
