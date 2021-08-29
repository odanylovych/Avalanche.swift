//
//  Transaction.swift
//  
//
//  Created by Yehor Popovych on 25.08.2021.
//

import Foundation

public protocol UnsignedTransaction {
    associatedtype Addr: AddressProtocol
    associatedtype Signed: SignedTransaction
    
    func toSigned(signatures: Dictionary<Addr, Signature>) throws -> Signed
}

public protocol ExtendedUnsignedTransaction: UnsignedTransaction {
    func serialized() throws -> Data
    func signingAddresses() throws -> [Addr.Extended]
}

public protocol SignedTransaction {
    func serialized() throws -> Data
}
