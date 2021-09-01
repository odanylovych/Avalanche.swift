//
//  AvaAddress.swift
//  
//
//  Created by Daniel Leping on 09/01/2021.
//

import Foundation
import UncommonCrypto

public struct Account: AccountProtocol, Equatable, Hashable {
    public typealias Addr = Address
    
    public let pubKey: Data
    public let path: Bip32Path
    private let chainCode: Data
    
    public var index: UInt32 { path.path[2] - Bip32Path.hard }
    
    public init(pubKey: Data, chainCode: Data, path: Bip32Path) throws {
        guard path.isValidAvalancheAccount else {
            throw AccountError.badBip32Path(path: path)
        }
        guard chainCode.count == 32 else {
            throw AccountError.badChainCodeLength(length: chainCode.count)
        }
        do {
            self.pubKey = try Algos.Avalanche.validatePubKey(pubKey: pubKey)
        } catch AvalancheAlgos.Error.badPublicKey {
            throw AccountError.badPublicKey(key: pubKey)
        }
        self.chainCode = chainCode
        self.path = path
    }
    
    public func derive(index: UInt32, change: Bool, hrp: String, chainId: String) throws -> ExtendedAddress {
        let path: Bip32Path
        do {
            path = try self.path
                .appending(change ? 1 : 0, hard: false)
                .appending(index, hard: false)
        } catch Bip32Path.Error.shouldBeSoft(_) {
            throw AccountError.badDerivationIndex(index: index)
        }
        let addrPub: (key: Data, chain: Data)
        do {
            let changePub = try Algos.Avalanche.derivePublic(pubKey: pubKey, chainCode: chainCode, index: path.path[3])
            addrPub = try Algos.Avalanche.derivePublic(pubKey: changePub.key, chainCode: changePub.chain, index: path.path[4])
        } catch AvalancheAlgos.Error.derivationFailed {
            throw AccountError.derivationFailed
        }
        do {
            let address = try Address(pubKey: addrPub.key, hrp: hrp, chainId: chainId)
            return try ExtendedAddress(address: address, path: path)
        } catch AddressError.badPublicKey(key: let pk) {
            throw AccountError.badPublicKey(key: pk)
        } catch AddressError.badBip32Path(path: let p) {
            throw AccountError.badBip32Path(path: p)
        }
    }
}

public struct Address: AddressProtocol, Equatable, Hashable {
    public typealias Extended = ExtendedAddress
    
    static let rawAddressSize = 20
    
    public let rawAddress: Data
    public let hrp: String
    public let chainId: String
    
    init(raw: Data, hrp: String, chainId: String) throws {
        guard raw.count == Self.rawAddressSize else {
            throw AddressError.badRawAddressLength(length: raw.count)
        }
        self.rawAddress = raw
        self.hrp = hrp
        self.chainId = chainId
    }
    
    public init(pubKey: Data, hrp: String, chainId: String) throws {
        let raw: Data
        do {
            raw = try Algos.Avalanche.address(pubKey: pubKey)
        } catch AvalancheAlgos.Error.badPublicKey {
            throw AddressError.badPublicKey(key: pubKey)
        }
        try self.init(raw: raw, hrp: hrp, chainId: chainId)
    }
    
    public init(bech: String) throws {
        let pd: (raw: Data, hrp: String, chainId: String)
        do {
            pd = try Algos.Avalanche.address(bech: bech)
        } catch is Bech32Error {
            throw AddressError.badAddressString(address: bech)
        }
        try self.init(raw: pd.raw, hrp: pd.hrp, chainId: pd.chainId)
    }
    
    public var bech: String {
        Algos.Avalanche.bech(address: rawAddress, hrp: hrp, chainId: chainId)!
    }
    
    public func verify(message: Data, signature: Signature) -> Bool {
        do {
            return try Algos.Avalanche.verify(address: rawAddress,
                                              message: message,
                                              signature: signature.raw)
        } catch {
            return false
        }
    }
    
    public func extended(path: Bip32Path) throws -> Extended {
        return try ExtendedAddress(address: self, path: path)
    }
}

extension Address: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(rawAddress, size: Self.rawAddressSize)
    }
}

public struct ExtendedAddress: ExtendedAddressProtocol {
    public typealias Base = Address
    
    public let address: Address
    public let path: Bip32Path
    
    public init(address: Address, path: Bip32Path) throws {
        guard path.isValidAvalancheAddress else {
            throw AddressError.badBip32Path(path: path)
        }
        self.address = address
        self.path = path
    }
    
    public var isChange: Bool { path.isChange! }
    public var accountIndex: UInt32 { path.accountIndex! }
    public var index: UInt32 { path.addressIndex! }
}
