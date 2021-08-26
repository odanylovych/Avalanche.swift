//
//  AlgosEtensions.swift
//  
//
//  Created by Yehor Popovych on 26.08.2021.
//

import Foundation
import UncommonCrypto
import CSecp256k1
import BigInt
#if !COCOAPODS
import Avalanche
#endif

extension AvalancheAlgos {
    public func sign(data: Data, with key: Data) -> Data? {
        let hash = SHA2.hash(type: .sha256, data: data)
        return Algos.Secp256k1.sign(hash: hash, with: key)
    }
}

extension EthereumAlgos {
    public func sign(data: Data, with key: Data) -> Data? {
        let hash = SHA3.hash(type: .keccak256, data: data)
        return Algos.Secp256k1.sign(hash: hash, with: key)
    }
}

extension Secp256k1Algos {
    public func sign(hash: [UInt8], with key: Data) -> Data? {
        var hash = hash
        var pk = key.bytes
        var sig = secp256k1_ecdsa_recoverable_signature()
        
        guard secp256k1_ecdsa_sign_recoverable(context, &sig, &hash, &pk, nil, nil) == 1 else {
            return nil
        }
            
        var output64 = Array<UInt8>(repeating: 0, count: 64)
        var recid: Int32 = 0
        secp256k1_ecdsa_recoverable_signature_serialize_compact(context, &output64, &recid, &sig)
            
        guard recid == 0 || recid == 1 else {
            return nil
        }
        return Data(output64 + [UInt8(recid)])
    }
    
    public func privateFromSeed(seed: Data) -> (pk: Data, cc: Data)? {
        guard seed.count >= 16 else { return nil }
        let hmacKey = Data("Bitcoin seed".utf8)
        let entropy = HMAC.authenticate(type: .sha512,
                                        key: hmacKey.bytes,
                                        data: seed)
        let chaincode = Data(entropy[32..<64])
        let privKeyCandidate = Data(entropy[0..<32])
        guard verifyPrivateKey(privateKey: privKeyCandidate) else { return nil }
        guard privateToPublic(privateKey: privKeyCandidate,
                              compressed: false) != nil else {
            return nil
        }
        return (privKeyCandidate, chaincode)
    }
    
    public func generateKey() -> (pk: Data, cc: Data)? {
        guard let seed = try? Data(SecureRandom.bytes(size: 32)) else { return nil }
        guard let key = try? SecureRandom.bytes(size: 32) else { return nil }
        let entropy = HMAC.authenticate(type: .sha512, key: key, data: seed)
        let privKeyCandidate = Data(entropy[0..<32])
        let chaincode = Data(entropy[32..<64])
        guard verifyPrivateKey(privateKey: privKeyCandidate) else { return nil }
        return (privKeyCandidate, chaincode)
    }
    
    public func derivePrivate(
        pk: Data, cc: Data, index: UInt32, hard: Bool
    ) -> (pk: Data, cc: Data)? {
        var entropy: Array<UInt8>
        var index = index
        if index >= Bip32Path.hard || hard {
            if index < Bip32Path.hard {
                index += Bip32Path.hard
            }
            var hmac = HMAC(type: .sha512, key: cc.bytes)
            hmac.update([UInt8(0x00)])
            hmac.update(pk)
            hmac.update(index.bigEndianBytes)
            entropy = hmac.finalize()
        } else {
            guard let pubKey = privateToPublic(privateKey: pk, compressed: true) else {
                return nil
            }
            var hmac = HMAC(type: .sha512, key: cc.bytes)
            hmac.update(pubKey)
            hmac.update(index.bigEndianBytes)
            entropy = hmac.finalize()
        }
        let newCC = Data(entropy[32..<64])
        let bn = BigUInt(Data(entropy[0..<32]))
        if bn > self.curveOrder {
            if index < UInt32.max {
                return derivePrivate(pk: pk, cc: cc, index: index+1, hard: hard)
            }
            return nil
        }
        let newPK = (bn + BigUInt(pk)) % self.curveOrder
        if newPK == BigUInt(0) {
            if index < UInt32.max {
                return derivePrivate(pk: pk, cc: cc, index: index+1, hard: hard)
            }
            return nil
        }
        let privKeyCandidate = newPK.serialize().setLengthLeft(32)!
        guard verifyPrivateKey(privateKey: privKeyCandidate) else { return nil }
        guard let pubKeyCandidate = privateToPublic(privateKey: privKeyCandidate,
                                                    compressed: true) else {
            return nil
        }
        guard pubKeyCandidate[0] == 0x02 || pubKeyCandidate[0] == 0x03 else { return nil }
        return (privKeyCandidate, newCC)
    }
}
