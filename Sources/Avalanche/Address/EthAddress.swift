//
//  EthAddress.swift
//  
//
//  Created by Yehor Popovych on 26.08.2021.
//

import Foundation

public struct EthAccount: AccountProtocol, ExtendedAddressProtocol, Equatable, Hashable {
    public let address: EthAddress
    public let path: Bip32Path
    
    public var index: UInt32 { accountIndex }
    public var isChange: Bool { false }
    public var accountIndex: UInt32 { path.path[2] - Bip32Path.hard }
    
    public init(pubKey: Data, path: Bip32Path) throws {
        let addr: EthAddress
        do {
            addr = try EthAddress(pubKey: pubKey)
        } catch AddressError.badPublicKey(key: let pk) {
            throw AccountError.badPublicKey(key: pk)
        }
        try self.init(address: addr, path: path)
    }
    
    public init(address: EthAddress, path: Bip32Path) throws {
        guard path.isValidEthereumAccount else {
            throw AccountError.badBip32Path(path: path)
        }
        self.address = address
        self.path = path
    }
}

public struct EthAddress: AddressProtocol, Equatable, Hashable {
    public typealias Extended = EthAccount
    
    public let rawAddress: Data
    
    public init(pubKey: Data) throws {
        guard let raw = Algos.Ethereum.address(from: pubKey) else {
            throw AccountError.badPublicKey(key: pubKey)
        }
        self.rawAddress = raw
    }
    
    public init(hex: String, eip55: Bool = false) throws {
        guard let addr = Algos.Ethereum.address(from: hex, eip55: eip55) else {
            throw AddressError.badAddressString(address: hex)
        }
        self.rawAddress = addr
    }
    
    public func hex(eip55: Bool = false) -> String {
        return Algos.Ethereum.hexAddress(rawAddress: rawAddress, eip55: eip55)
    }
    
    public func verify(message: Data, signature: Signature) -> Bool {
        return Algos.Ethereum.verify(address: rawAddress,
                                     message: message,
                                     signature: signature) ?? false
    }
    
    public func extended(path: Bip32Path) throws -> Extended {
        do {
            return try EthAccount(address: self, path: path)
        } catch AccountError.badBip32Path(path: let p) {
            throw AddressError.badBip32Path(path: p)
        }
    }
}
