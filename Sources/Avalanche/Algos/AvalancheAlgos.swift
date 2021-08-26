//
//  AvalancheAlgos.swift
//  
//
//  Created by Daniel Leping on 09/01/2021.
//

import Foundation
import BigInt
import UncommonCrypto

public struct AvalancheAlgos {
    public enum Error: Swift.Error {
        case badPublicKey
        case publicHardDerivation
        case derivationFailed
        case badSignature
    }
    
    internal init() {}
    
    public func address(bech: String) throws -> (raw: Data, hrp: String, chainId: String) {
        try Algos.Bech.parse(address: bech).get()
    }
    
    public func address(pubKey: Data) throws -> Data {
        let mPubKey = try validatePubKey(pubKey: pubKey).bytes
        let hash1 = SHA2.hash(type: .sha256, bytes: mPubKey)
        return RIPEMD160.hash(message: Data(hash1))
    }
    
    public func verify(address: Data, message: Data, signature: Data) throws -> Bool {
        let hash = SHA2.hash(type: .sha256, data: message)
        guard let pub = Algos.Secp256k1.recoverPublicKey(signature: signature, hash: hash) else {
            throw Error.badSignature
        }
        return try address == self.address(pubKey: pub)
    }
    
    public func validatePubKey(pubKey: Data) throws -> Data {
        guard var parsed = Algos.Secp256k1.parsePublicKey(serializedKey: pubKey) else {
            throw Error.badPublicKey
        }
        guard let mPubKey = Algos.Secp256k1.serializePublicKey(publicKey: &parsed, compressed: true) else {
            throw Error.badPublicKey
        }
        return mPubKey
    }
    
    public func bech(address: Data, hrp: String, chainId: String) -> String? {
        try? Algos.Bech.address(from: address, hrp: hrp, chainId: chainId).get()
    }
    
    public func derivePublic(pubKey: Data, chainCode: Data, index: UInt32) throws -> (key: Data, chain: Data) {
        let pub = try validatePubKey(pubKey: pubKey)
        guard let derived = Algos.Secp256k1.derivePublic(pubKey: pub, chainCode: chainCode, index: index) else {
            throw Error.derivationFailed
        }
        return derived
    }
}
