//
//  Secp.swift
//  
//
//  Created by Daniel Leping on 28/12/2020.
//

import Foundation

import CSecp256k1
import UncommonCrypto

public struct SECP256K1 {
    static let context: OpaquePointer = {
        var seed = try! SecureRandom.bytes(size: 32)
        let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN|SECP256K1_CONTEXT_VERIFY))
        let _ = secp256k1_context_randomize(context!, &seed)
        return context!
    }()

    public static func privateToPublic(privateKey: Data, compressed: Bool = false) -> Data? {
        if (privateKey.count != 32) {return nil}
        guard var publicKey = SECP256K1.privateKeyToPublicKey(privateKey: privateKey) else {return nil}
        guard let serializedKey = serializePublicKey(publicKey: &publicKey, compressed: compressed) else {return nil}
        return serializedKey
    }
    
    internal static func privateKeyToPublicKey(privateKey: Data) -> secp256k1_pubkey? {
        if (privateKey.count != 32) {return nil}
        var publicKey = secp256k1_pubkey()
        let result: Int32 = privateKey.withUnsafeBytes { ptr in
            secp256k1_ec_pubkey_create(context, &publicKey, ptr.bindMemory(to: UInt8.self).baseAddress!)
        }
        if result == 0 {
            return nil
        }
        return publicKey
    }
    
    public static func serializePublicKey(publicKey: inout secp256k1_pubkey, compressed: Bool = false) -> Data? {
        var keyLength = compressed ? 33 : 65
        var serializedPubkey = Array(repeating: UInt8(0x00), count: keyLength)
        let result = secp256k1_ec_pubkey_serialize(
            context, &serializedPubkey, &keyLength, &publicKey,
            UInt32(compressed ? SECP256K1_EC_COMPRESSED : SECP256K1_EC_UNCOMPRESSED)
        )
        if result == 0 {
            return nil
        }
        return Data(serializedPubkey)
    }
    
    public static func verifyPrivateKey(privateKey: Data) -> Bool {
        if (privateKey.count != 32) {return false}
        let result: Int32 = privateKey.withUnsafeBytes { ptr in
            secp256k1_ec_seckey_verify(context, ptr.bindMemory(to: UInt8.self).baseAddress!)
        }
        return result == 1
    }
    
    public static func combineSerializedPublicKeys(keys: [Data], outputCompressed: Bool = false) -> Data? {
        let numToCombine = keys.count
        guard numToCombine >= 1 else { return nil}
        
        let pubKeys = keys.compactMap { SECP256K1.parsePublicKey(serializedKey: $0) }
        guard pubKeys.count == keys.count else { return nil }
        
        var publicKey: secp256k1_pubkey = secp256k1_pubkey()
        var rcaller: (([secp256k1_pubkey], [UnsafePointer<secp256k1_pubkey>?]) -> Int32)? = nil
        rcaller = { (keys: [secp256k1_pubkey], pointers: [UnsafePointer<secp256k1_pubkey>?]) -> Int32 in
            if keys.count == 0 {
                return secp256k1_ec_pubkey_combine(context, &publicKey, pointers, pointers.count)
            }
            return withUnsafePointer(to: keys.first!) { ptr in
                rcaller!(Array(keys.dropFirst()), pointers + [ptr])
            }
        }
        
        let result = rcaller!(pubKeys, [])
        if result == 0 {
            return nil
        }
        let serializedKey = SECP256K1.serializePublicKey(publicKey: &publicKey, compressed: outputCompressed)
        return serializedKey
    }
    
    internal static func parsePublicKey(serializedKey: Data) -> secp256k1_pubkey? {
        guard serializedKey.count == 33 || serializedKey.count == 65 else {
            return nil
        }
        let keyLen: Int = Int(serializedKey.count)
        var publicKey = secp256k1_pubkey()
        let result: Int32 = serializedKey.withUnsafeBytes { ptr in
            secp256k1_ec_pubkey_parse(context, &publicKey, ptr.bindMemory(to: UInt8.self).baseAddress!, keyLen)
        }
        if result == 0 {
            return nil
        }
        return publicKey
    }
    
    static func sign(data: [UInt8], with key: Data) -> Data? {
        var message = data
        
        var pk = key.bytes
        var sig = secp256k1_ecdsa_recoverable_signature()

        guard secp256k1_ecdsa_sign_recoverable(SECP256K1.context, &sig, &message, &pk, nil, nil) == 1 else {
            return nil
        }
        
        var output64 = Array<UInt8>(repeating: 0, count: 64)
        var recid: Int32 = 0
        secp256k1_ecdsa_recoverable_signature_serialize_compact(SECP256K1.context, &output64, &recid, &sig)
        
        guard recid == 0 || recid == 1 else {
            return nil
        }
        
        var response = Data(output64)
        response.append(UInt8(recid))
        return response
    }
    
    public static func generateKey(seed: Data? = nil) -> Data? {
        guard let seed = (seed != nil ? seed : try? Data(SecureRandom.bytes(size: 32))) else { return nil }
        guard seed.count >= 16 else { return nil }
        guard let key = try? SecureRandom.bytes(size: 32) else { return nil }
        let entropy = HMAC.authenticate(type: .sha512, key: key, data: seed)
        guard entropy.count == 64 else { return nil }
        let I_L = entropy[0..<32]
        let privKeyCandidate = Data(I_L)
        guard SECP256K1.verifyPrivateKey(privateKey: privKeyCandidate) else { return nil }
        
        return privKeyCandidate
    }
}
