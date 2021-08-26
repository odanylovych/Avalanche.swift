//
//  Data+Helpers.swift
//  
//
//  Created by Yehor Popovych on 26.08.2021.
//

import Foundation

extension UInt32 {
    public var bigEndianBytes: [UInt8] {
        withUnsafePointer(to: bigEndian) {
            $0.withMemoryRebound(to: UInt8.self, capacity: self.bitWidth / 8) {
                return Array(UnsafeBufferPointer(start: $0, count: self.bitWidth / 8))
            }
        }
    }
}

extension Data {
    public var bytes: Array<UInt8> {
        return Array(self)
    }
    
    public init?(hex: String) {
        let prefix = hex.hasPrefix("0x") ? 2 : 0
        guard let hData = hex.data(using: .ascii) else {
            return nil
        }
        let parsed: Data? = hData.withUnsafeBytes { hex in
            var result = Data()
            result.reserveCapacity((hex.count - prefix) / 2)
            var current: UInt8? = nil
            for indx in prefix ..< hex.count {
                let v: UInt8
                switch hex[indx] {
                case let c where c <= 57: v = c - 48
                case let c where c >= 65 && c <= 70: v = c - 55
                case let c where c >= 97: v = c - 87
                default:
                    return nil
                }
                if let val = current {
                    result.append(val << 4 | v)
                    current = nil
                } else {
                    current = v
                }
            }
            return result
        }
        guard let parsed = parsed else {
            return nil
        }
        self = parsed
    }
    
    public func hex(prefix: Bool = true) -> String {
        var result = Array<UInt8>()
        result.reserveCapacity(count * 2 + (prefix ? 2 : 0))
        if prefix {
            result.append(UInt8(ascii: "0"))
            result.append(UInt8(ascii: "x"))
        }
        for byte in self {
            result.append(Self._hex_characters[Int(byte >> 4)])
            result.append(Self._hex_characters[Int(byte & 0x0F)])
        }
        return String(bytes: result, encoding: .ascii)!
    }
    
    public func setLengthLeft(_ toBytes: UInt64, isNegative:Bool = false ) -> Data? {
        let existingLength = UInt64(self.count)
        if (existingLength == toBytes) {
            return Data(self)
        } else if (existingLength > toBytes) {
            return nil
        }
        var data = Data()
        data.reserveCapacity(Int(toBytes))
        if (isNegative) {
            data.append(Data(repeating: UInt8(255), count: Int(toBytes - existingLength)))
        } else {
            data.append(Data(repeating: UInt8(0), count: Int(toBytes - existingLength)))
        }
        data.append(self)
        return data
    }
    
    private static let _hex_characters: [UInt8] = [
        UInt8(ascii: "0"), UInt8(ascii: "1"), UInt8(ascii: "2"), UInt8(ascii: "3"),
        UInt8(ascii: "4"), UInt8(ascii: "5"), UInt8(ascii: "6"), UInt8(ascii: "7"),
        UInt8(ascii: "8"), UInt8(ascii: "9"), UInt8(ascii: "a"), UInt8(ascii: "b"),
        UInt8(ascii: "c"), UInt8(ascii: "d"), UInt8(ascii: "e"), UInt8(ascii: "f")
    ]
}
