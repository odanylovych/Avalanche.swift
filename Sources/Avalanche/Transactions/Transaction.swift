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
}

public protocol ExtendedUnsignedTransaction: UnsignedTransaction {
    func serialized() throws -> Data
    func signingAddresses() throws -> [Addr.Extended]
    func toSigned(signatures: Dictionary<Addr, Signature>) throws -> Signed
}

public protocol SignedTransaction {
}
