//
//  Secp256k1Algos.swift
//  
//
//  Created by Daniel Leping on 28/12/2020.
//

import Foundation
import BigInt
import secp256k1
import UncommonCrypto

public struct Secp256k1Algos {
    public let context: OpaquePointer!
    
    internal init() {
        var seed = try! SecureRandom.bytes(size: 32)
        let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN|SECP256K1_CONTEXT_VERIFY))
        let _ = secp256k1_context_randomize(context!, &seed)
        self.context = context
    }
    
    public func privateToPublic(privateKey: Data, compressed: Bool = false) -> Data? {
        if (privateKey.count != 32) {return nil}
        guard var publicKey = privateKeyToPublicKey(privateKey: privateKey) else {return nil}
        guard let serializedKey = serializePublicKey(publicKey: &publicKey, compressed: compressed) else {return nil}
        return serializedKey
    }
    
    private func privateKeyToPublicKey(privateKey: Data) -> secp256k1_pubkey? {
        if (privateKey.count != 32) {return nil}
        var publicKey = secp256k1_pubkey()
        let result: Int32 = privateKey.withUnsafeBytes { ptr in
            secp256k1_ec_pubkey_create(context, &publicKey,
                                       ptr.bindMemory(to: UInt8.self).baseAddress!)
        }
        if result == 0 { return nil }
        return publicKey
    }
    
    internal func serializePublicKey(publicKey: inout secp256k1_pubkey,
                                     compressed: Bool = false) -> Data? {
        var keyLength = compressed ? 33 : 65
        var serializedPubkey = Array(repeating: UInt8(0x00), count: keyLength)
        let result = secp256k1_ec_pubkey_serialize(
            context, &serializedPubkey, &keyLength, &publicKey,
            UInt32(compressed ? SECP256K1_EC_COMPRESSED : SECP256K1_EC_UNCOMPRESSED)
        )
        if result == 0 { return nil }
        return Data(serializedPubkey)
    }
    
    public func verifyPrivateKey(privateKey: Data) -> Bool {
        if (privateKey.count != 32) {return false}
        let result: Int32 = privateKey.withUnsafeBytes { ptr in
            secp256k1_ec_seckey_verify(context,
                                       ptr.bindMemory(to: UInt8.self).baseAddress!)
        }
        return result == 1
    }
    
    public func combineSerializedPublicKeys(keys: [Data], outputCompressed: Bool = false) -> Data? {
        let numToCombine = keys.count
        guard numToCombine >= 1 else { return nil}
        
        let pubKeys = keys.compactMap { parsePublicKey(serializedKey: $0) }
        guard pubKeys.count == keys.count else { return nil }
        
        var publicKey: secp256k1_pubkey = secp256k1_pubkey()
        var rcaller: (([secp256k1_pubkey], [UnsafePointer<secp256k1_pubkey>?]) -> Int32)? = nil
        rcaller = { (keys: [secp256k1_pubkey], pointers: [UnsafePointer<secp256k1_pubkey>?]) -> Int32 in
            if keys.count == 0 {
                return secp256k1_ec_pubkey_combine(self.context, &publicKey, pointers, pointers.count)
            }
            return withUnsafePointer(to: keys.first!) { ptr in
                rcaller!(Array(keys.dropFirst()), pointers + [ptr])
            }
        }
        
        let result = rcaller!(pubKeys, [])
        if result == 0 {
            return nil
        }
        let serializedKey = serializePublicKey(publicKey: &publicKey, compressed: outputCompressed)
        return serializedKey
    }
    
    internal func parsePublicKey(serializedKey: Data) -> secp256k1_pubkey? {
        guard serializedKey.count == 33 || serializedKey.count == 65 else {
            return nil
        }
        let keyLen: Int = Int(serializedKey.count)
        var publicKey = secp256k1_pubkey()
        let result: Int32 = serializedKey.withUnsafeBytes { ptr in
            secp256k1_ec_pubkey_parse(context, &publicKey,
                                      ptr.bindMemory(to: UInt8.self).baseAddress!,
                                      keyLen)
        }
        if result == 0 { return nil }
        return publicKey
    }
    
    public func derivePublic(pubKey: Data, chainCode: Data, index: UInt32) -> (key: Data, chain: Data)? {
        guard index < Bip32Path.hard else { return nil }
        guard var parsed = parsePublicKey(serializedKey: pubKey) else {
            return nil
        }
        guard let pubKey = serializePublicKey(publicKey: &parsed, compressed: true) else {
            return nil
        }
        var hmac = HMAC(type: .sha512, key: chainCode.bytes)
        hmac.update(pubKey)
        hmac.update(index.bigEndianBytes)
        let entropy = hmac.finalize()
        let cc = Data(entropy[32..<64])
        let bn = BigUInt(Data(entropy[0..<32]))
        if bn > self.curveOrder {
            if index < UInt32.max {
                return derivePublic(pubKey: pubKey, chainCode: chainCode, index: index+1)
            }
            return nil
        }
        let tempKey = bn.serialize().setLengthLeft(32)!
        guard verifyPrivateKey(privateKey: tempKey) else {
            return nil
        }
        guard let pubKeyCandidate = privateToPublic(privateKey: tempKey, compressed: true) else {
            return nil
        }
        guard let newPublicKey = combineSerializedPublicKeys(keys: [pubKey, pubKeyCandidate], outputCompressed: true) else {
           return nil
        }
        return (newPublicKey, cc)
    }
    
    public func recoverPublicKey(signature: Data, hash: [UInt8]) -> Data? {
        guard signature.count == 65 else { return nil }
        let recid = signature.last!
        let data64 = Array(signature.dropLast())
        var sig = secp256k1_ecdsa_recoverable_signature()
        
        guard secp256k1_ecdsa_recoverable_signature_parse_compact(context, &sig, data64, Int32(recid)) == 1 else {
            return nil
        }
        
        var pub = secp256k1_pubkey()
        guard secp256k1_ecdsa_recover(context, &pub, &sig, hash) == 1 else {
            return nil
        }
        return serializePublicKey(publicKey: &pub, compressed: false)
    }
    
    public let curveOrder = BigUInt(
        "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141",
        radix: 16
    )!
}
