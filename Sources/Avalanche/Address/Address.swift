//
//  Address.swift
//  
//
//  Created by Daniel Leping on 08/01/2021.
//

import Foundation

public enum AddressError: Error {
    case badPublicKey(key: Data)
    case badBip32Path(path: Bip32Path)
    case badAddressString(address: String)
    case badRawAddressLength(length: Int)
}

public enum AccountError: Error {
    case badBip32Path(path: Bip32Path)
    case badPublicKey(key: Data)
    case badChainCodeLength(length: Int)
    case badDerivationIndex(index: UInt32)
    case derivationFailed
}

public protocol AccountProtocol: Hashable {
    associatedtype Addr: AddressProtocol
    
    var path: Bip32Path { get }
    var index: UInt32 { get }
}

public protocol AddressProtocol: Hashable where Extended.Base == Self {
    associatedtype Extended: ExtendedAddressProtocol
    
    func verify(message: Data, signature: Signature) -> Bool
    func extended(path: Bip32Path) throws -> Extended
}

public protocol ExtendedAddressProtocol: Hashable where Base.Extended == Self {
    associatedtype Base: AddressProtocol
    
    var address: Base { get }
    var path: Bip32Path { get }
    var isChange: Bool { get }
    var accountIndex: UInt32 { get }
    var index: UInt32 { get }
}
