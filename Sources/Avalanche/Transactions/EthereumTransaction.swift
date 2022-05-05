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

extension EthereumTransaction: UnsignedTransaction, SignedTransaction {
    public typealias Addr = EthereumAddress
    public typealias Signed = Self
}

public struct ExtendedEthereumTransaction: ExtendedUnsignedTransaction {
    public typealias Addr = EthereumAddress
    public typealias Signed = EthereumTransaction
    
    public let transaction: EthereumTransaction
    public let account: Addr.Extended
    public let chainID: BigUInt
    
    public init(transaction: EthereumTransaction, account: Addr.Extended, chainID: BigUInt) {
        self.transaction = transaction
        self.account = account
        self.chainID = chainID
    }
    
    public func serialized() throws -> Data {
        guard let data = transaction.encode(forSignature: true, chainID: chainID) else {
            throw EthereumTransactionError.encodeError
        }
        return data
    }
    
    public func toSigned(signatures: Dictionary<EthereumAddress, Signature>) throws -> EthereumTransaction {
        guard let signature = signatures[account.address] else {
            throw EthereumTransactionError.noSignature(for: account.address)
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
        var transaction = transaction
        transaction.v = BigUInt(v) + d + chainID + chainID
        transaction.r = BigUInt(r)
        transaction.s = BigUInt(s)
        return transaction
    }
    
    public func signingAddresses() throws -> [Addr.Extended] {
        [account]
    }
}
