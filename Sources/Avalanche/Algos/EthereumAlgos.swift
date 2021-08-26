//
//  EthereumAlgos.swift
//  
//
//  Created by Daniel Leping on 09/01/2021.
//

import Foundation
import UncommonCrypto

public struct EthereumAlgos {
    internal init() {}
    
    public func address(from pub: Data) -> Data? {
        guard var parsed = Algos.Secp256k1.parsePublicKey(serializedKey: pub) else { return nil }
        guard var mPubKey = Algos.Secp256k1.serializePublicKey(publicKey: &parsed, compressed: false)?.bytes else { return nil }
        mPubKey.remove(at: 0)
        let hash = SHA3.hash(type: .keccak256, bytes: mPubKey)
        guard hash.count == 32 else {
            return nil
        }
        return Data(hash[12...])
    }
    
    public func verify(address: Data, message: Data, signature: Data) -> Bool? {
        let hash = SHA3.hash(type: .keccak256, data: message)
        guard let pub = Algos.Secp256k1.recoverPublicKey(signature: signature, hash: hash) else {
            return nil
        }
        return address == self.address(from: pub)
    }
    
    public func address(from hex: String, eip55: Bool) -> Data? {
        // Check length
        guard hex.count == 40 || hex.count == 42 else {
            return nil
        }
        
        var hex = hex
        
        // Check prefix
        if hex.count == 42 {
            let s = hex.index(hex.startIndex, offsetBy: 0)
            let e = hex.index(hex.startIndex, offsetBy: 2)
            
            guard String(hex[s..<e]) == "0x" else {
                return nil
            }
            
            // Remove prefix
            hex = String(hex[s...])
        }
        
        guard let addressBytes = Data(hex: hex), addressBytes.count == 20 else {
            return nil
        }
        
        // EIP 55 checksum
        // See: https://github.com/ethereum/EIPs/blob/master/EIPS/eip-55.md
        if eip55 {
            let hash = SHA3.hash(type: .keccak256, bytes: Array(hex.lowercased().utf8))
            
            for i in 0..<hex.count {
                let charString = String(hex[hex.index(hex.startIndex, offsetBy: i)])
                if charString.rangeOfCharacter(from: Self.hexadecimalNumbers) != nil {
                    continue
                }
                
                let bytePos = (4 * i) / 8
                let bitPos = (4 * i) % 8
                guard bytePos < hash.count && bitPos < 8 else {
                    return nil
                }
                let bit = (hash[bytePos] >> (7 - UInt8(bitPos))) & 0x01
                
                if charString.lowercased() == charString && bit == 1 {
                    return nil
                } else if charString.uppercased() == charString && bit == 0 {
                    return nil
                }
            }
        }
        return addressBytes
    }
    
    public func hexAddress(rawAddress: Data, eip55: Bool) -> String {
        if !eip55 {
            return rawAddress.hex(prefix: true)
        } else {
            let address = rawAddress.hex(prefix: false)
            let hash = SHA3.hash(type: .keccak256, bytes: Array(address.utf8))
            
            var hex = "0x"
            for i in 0..<address.count {
                let charString = String(address[address.index(address.startIndex, offsetBy: i)])
                
                if charString.rangeOfCharacter(from: Self.hexadecimalNumbers) != nil {
                    hex += charString
                    continue
                }
                
                let bytePos = (4 * i) / 8
                let bitPos = (4 * i) % 8
                let bit = (hash[bytePos] >> (7 - UInt8(bitPos))) & 0x01
                
                if bit == 1 {
                    hex += charString.uppercased()
                } else {
                    hex += charString.lowercased()
                }
            }
            return hex
        }
    }
    
    private static let hexadecimalNumbers: CharacterSet = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
}
