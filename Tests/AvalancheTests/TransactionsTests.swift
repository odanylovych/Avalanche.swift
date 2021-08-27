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
        let encoded = try AEncoder().encode(actual).output.map { $0 }
        XCTAssertEqual(encoded, expected)
    }
    
    private func encodeFixedTest(actual: AvalancheFixedEncodable, expected: [UInt8], size: Int) throws {
        let encoded = try AEncoder().encode(actual, size).output.map { $0 }
        XCTAssertEqual(encoded, expected)
    }

    func testEncodeByte() throws {
        try encodeTest(
            actual: UInt8(0x01),
            expected: [0x01]
        )
    }

    func testEncodeShort() throws {
        try encodeTest(
            actual: UInt16(0x0102),
            expected: [0x01, 0x02]
        )
    }

    func testEncodeInteger() throws {
        try encodeTest(
            actual: UInt32(0x01020304),
            expected: [0x01, 0x02, 0x03, 0x04]
        )
    }

    func testEncodeLongInteger() throws {
        try encodeTest(
            actual: UInt64(0x0102030405060708),
            expected: [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]
        )
    }

    func testEncodeIPAddresses() throws {
        try encodeTest(
            actual: IPv4Address(host: (127, 0, 0, 1), port: 9650),
            expected: [
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x7f, 0x00, 0x00, 0x01,
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
        try encodeFixedTest(
            actual: [UInt8(0x01), UInt8(0x02)],
            expected: [0x01, 0x02],
            size: 2
        )
        try encodeFixedTest(
            actual: [UInt32(0x03040506)],
            expected: [0x03, 0x04, 0x05, 0x06],
            size: 1
        )
    }

    func testEncodeVariableLengthArray() throws {
        try encodeTest(
            actual: [UInt8(0x01), UInt8(0x02)],
            expected: [0x00, 0x00, 0x00, 0x02, 0x01, 0x02]
        )
        try encodeTest(
            actual: [UInt32(0x03040506)],
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
