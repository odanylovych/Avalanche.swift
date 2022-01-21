//
//  File.swift
//  
//
//  Created by Daniel Leping on 09/01/2021.
//

import Foundation
#if !COCOAPODS
import Avalanche
#endif

public struct KeyPair {
    public enum Error: Swift.Error {
        case badPrivateKey
        case badSeed(seed: Data)
        case badChainCodeLength(length: Int)
        case badStringPartsCount(count: Int)
        case badStringPrefix(prefix: String)
        case badBase58(b58: String)
        case deriveFailed
    }
    
    public let publicKey: Data
    public let chainCode: Data?
    private let _sk: Data
    
    public init(sk: Data, chainCode: Data?) throws {
        guard let pub = Algos.Secp256k1.privateToPublic(privateKey: sk, compressed: true) else {
            throw Error.badPrivateKey
        }
        guard chainCode?.count ?? 32 == 32 else {
            throw Error.badChainCodeLength(length: chainCode!.count)
        }
        self._sk = sk
        self.chainCode = chainCode
        self.publicKey = pub
    }
}

public extension KeyPair {
    /// import from string
    init(key: String) throws {
        let parts = key.split(separator: "-")
        guard parts.count == 2 else {
            throw Error.badStringPartsCount(count: parts.count)
        }
        guard parts[0] == "PrivateKey" else {
            throw Error.badStringPrefix(prefix: String(parts[0]))
        }
        guard let pk = Algos.Base58.from(cb58: String(parts[1])) else {
            throw Error.badBase58(b58: String(parts[1]))
        }
        try self.init(sk: pk, chainCode: nil)
    }
    
    init(seed: Data) throws {
        guard let gen = Algos.Secp256k1.privateFromSeed(seed: seed) else {
            throw Error.badSeed(seed: seed)
        }
        try self.init(sk: gen.pk, chainCode: gen.cc)
    }
    
    func derive(index: UInt32, hard: Bool) throws -> KeyPair {
        guard let cc = chainCode else {
            throw Error.badChainCodeLength(length: 0)
        }
        guard let der = Algos.Secp256k1.derivePrivate(pk: _sk, cc: cc, index: index, hard: hard) else {
            throw Error.deriveFailed
        }
        return try KeyPair(sk: der.pk, chainCode: der.cc)
    }
    
    func address(hrp: String, chainId: String) -> Address {
        try! Address(pubKey: publicKey, hrp: hrp, chainId: chainId)
    }
    
    var ethAddress: EthAddress {
        try! EthAddress(pubKey: publicKey)
    }
    
    func signAvalanche(serialized tx: Data) -> Signature? {
        guard let data = Algos.Avalanche.sign(data: tx, with: _sk) else {
            return nil
        }
        return Signature(data: data)
    }
    
    func signAvalanche(message data: Data) -> Signature? {
        let prefixed = Data("\u{1A}Avalanche Signed Message:\n".utf8) +
            UInt32(data.count).bigEndianBytes + data
        guard let data = Algos.Avalanche.sign(data: prefixed, with: _sk) else {
            return nil
        }
        return Signature(data: data)
    }
    
    func signEthereum(message data: Data) -> Signature? {
        let prefixed = Data("\u{19}Ethereum Signed Message:\n".utf8) + Data(String(data.count, radix: 10).utf8) + data
        guard let data = Algos.Ethereum.sign(data: prefixed, with: _sk) else {
            return nil
        }
        return Signature(data: data)
    }
    
    func signEthereum(serialized tx: Data) -> Signature? {
        guard let data = Algos.Ethereum.sign(data: tx, with: _sk) else {
            return nil
        }
        return Signature(data: data)
    }
    
    var privateString: String {
        "PrivateKey-" + Algos.Base58.cb58(data: _sk)
    }
    
    var privateData: Data {
        _sk
    }
    
    var publicString: String {
        Algos.Base58.cb58(data: publicKey)
    }
    
    static func generate() -> KeyPair? {
        try? Algos.Secp256k1.generateKey().flatMap {
            try KeyPair(sk: $0.pk, chainCode: $0.cc)
        }
    }
}
