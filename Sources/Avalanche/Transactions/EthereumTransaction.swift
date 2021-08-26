//
//  EthereumTransaction.swift
//  
//
//  Created by Yehor Popovych on 26.08.2021.
//

import Foundation

public struct UnsignedEthereumTransaction: UnsignedTransaction {
    public typealias Addr = EthAddress
    public typealias Signed = SignedEthereumTransaction
    
    // TODO: Implement
    public func toSigned(signatures: Dictionary<EthAddress, Signature>) throws -> SignedEthereumTransaction {
        fatalError("Not implemented")
    }
}

public struct SignedEthereumTransaction: SignedTransaction {
    // TODO: Implement
    
    public func serialized() throws -> Data {
        fatalError("Not implemented")
    }
}

public struct EthereumTransactionExt: ExtendedUnsignedTransaction {
    public typealias Addr = EthAddress
    public typealias Signed = SignedEthereumTransaction
    
    public let transaction: UnsignedEthereumTransaction
    public let pathes: Dictionary<Addr, Bip32Path>
    public let chainId: UInt64
    
    public init(tx: UnsignedEthereumTransaction, chainId: UInt64, pathes: Dictionary<Addr, Bip32Path>) {
        self.transaction = tx
        self.pathes = pathes
        self.chainId = chainId
    }
    
    public func serialized() throws -> Data {
        fatalError("Not implemented")
    }
    
    public func toSigned(signatures: Dictionary<EthAddress, Signature>) throws -> SignedEthereumTransaction {
        try transaction.toSigned(signatures: signatures)
    }
    
    public func signingAddresses() throws -> [Addr.Extended] {
        fatalError("Not implemented")
    }
}
