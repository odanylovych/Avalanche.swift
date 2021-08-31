//
//  Base58Algos.swift
//  
//
//  Created by Yehor Popovych on 31.08.2021.
//

import Foundation
import BigInt
import UncommonCrypto

public struct Base58Algos {
    public static let checksumLength = 4
    public static let b58Alphabet = [UInt8]("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".utf8)
    
    public func b58(data: Data, alphabet: [UInt8] = Self.b58Alphabet) -> String {
        var x = BigUInt(data)
        let radix = BigUInt(alphabet.count)

        var answer = [UInt8]()
        answer.reserveCapacity(data.count)

        while x > 0 {
            let (quotient, modulus) = x.quotientAndRemainder(dividingBy: radix)
            answer.append(alphabet[Int(modulus)])
            x = quotient
        }

        let prefix = Array(data.prefix(while: {$0 == 0})).map { _ in alphabet[0] }
        answer.append(contentsOf: prefix)
        answer.reverse()
        return String(bytes: answer, encoding: .utf8)!
    }

    public func from(b58: String, alphabet: [UInt8] = Self.b58Alphabet) -> Data? {
        var answer = BigUInt(0)
        var j = BigUInt(1)
        let radix = BigUInt(alphabet.count)
        let byteString = [UInt8](b58.utf8)

        for ch in byteString.reversed() {
            if let index = alphabet.firstIndex(of: ch) {
                answer = answer + (j * BigUInt(index))
                j *= radix
            } else {
                return nil
            }
        }

        let bytes = answer.serialize()
        return byteString.prefix(while: { i in i == alphabet[0]}).map{ _ in 0 } + bytes
    }
    
    public func from(cb58: String, alphabet: [UInt8] = Self.b58Alphabet) -> Data? {
        guard let b58data = from(b58: cb58, alphabet: alphabet) else {
            return nil
        }
        let prefix = b58data.prefix(b58data.count - Self.checksumLength)
        let checksum = b58data.suffix(Self.checksumLength)
        let calculated = SHA2.hash(type: .sha256, data: Data(prefix))
        guard Data(calculated.suffix(Self.checksumLength)) == checksum else {
            return nil
        }
        return Data(prefix)
    }
    
    public func cb58(data: Data, alphabet: [UInt8] = Self.b58Alphabet) -> String {
        let checksum = SHA2.hash(type: .sha256, data: data)
        return b58(data: data + checksum.suffix(Self.checksumLength),
                   alphabet: alphabet)
    }
}
