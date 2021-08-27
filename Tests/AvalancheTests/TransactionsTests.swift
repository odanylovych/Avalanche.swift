//
//  TransactionsTests.swift
//  
//
//  Created by Ostap Danylovych on 25.08.2021.
//

import Foundation
import XCTest
@testable import Avalanche

final class TransactionsTests: AvalancheTestCase {
    private func encodeTest(actual: AvalancheEncodable, expected: [UInt8]) throws {
        let encoder = AEncoder()
        let encoded = try encoder.encode(actual).output.map { $0 }
        XCTAssertEqual(encoded, expected)
    }
    
    func testEncodeByte() throws {
        try encodeTest(
            actual: UInt8(1),
            expected: [0x01]
        )
    }
    
    func testEncodeShort() throws {
        try encodeTest(
            actual: UInt16(258),
            expected: [0x01, 0x02]
        )
    }
    
    func testEncodeInteger() throws {
        try encodeTest(
            actual: UInt32(16909060),
            expected: [0x01, 0x02, 0x03, 0x04]
        )
    }
    
    func testEncodeLongInteger() throws {
        try encodeTest(
            actual: UInt64(72623859790382856),
            expected: [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]
        )
    }
    
    func testEncodeIPAddresses() throws {
        try encodeTest(
            actual: IPv4Address(host: (127, 0, 0, 1), port: 9650),
            expected: [
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0xff, 0xff, 0x7f, 0x00, 0x00, 0x01,
                0x25, 0xb2
            ]
        )
        try encodeTest(
            actual: IPv6Address(host: ["2001", "0db8", "ac10", "fe01"], port: 12345),
            expected: [
                0x20, 0x01, 0x0d, 0xb8, 0xac, 0x10, 0xfe, 0x01,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x30, 0x39
            ]
        )
    }
    
    func testEncodeFixedLengthArray() throws {
        struct FixedArrayUInt8: FixedArray {
            typealias E = UInt8
            
            static var count: UInt32 = 2
            var array: [UInt8]
            
            init?(array: [UInt8]) {
                guard array.count == Self.count else {
                    return nil
                }
                self.array = array
            }
        }
        struct FixedArrayUInt32: FixedArray {
            typealias E = UInt32
            
            static var count: UInt32 = 1
            var array: [UInt32]
            
            init?(array: [UInt32]) {
                guard array.count == Self.count else {
                    return nil
                }
                self.array = array
            }
        }
        try encodeTest(
            actual: FixedArrayUInt8(array: [UInt8(1), UInt8(2)])!,
            expected: [0x01, 0x02]
        )
        try encodeTest(
            actual: FixedArrayUInt32(array: [UInt32(50595078)])!,
            expected: [0x03, 0x04, 0x05, 0x06]
        )
    }
    
    func testEncodeVariableLengthArray() throws {
        try encodeTest(
            actual: [UInt8(1), UInt8(2)],
            expected: [0x00, 0x00, 0x00, 0x02, 0x01, 0x02]
        )
        try encodeTest(
            actual: [UInt32(50595078)],
            expected: [0x00, 0x00, 0x00, 0x01, 0x03, 0x04, 0x05, 0x06]
        )
    }
    
    func testEncodeString() throws {
        try encodeTest(
            actual: "Avax",
            expected: [0x00, 0x04, 0x41, 0x76, 0x61, 0x78]
        )
    }
}
