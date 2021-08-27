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
        let encoded = try AEncoder().encode(actual, size: size).output.map { $0 }
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
            actual: IPv6Address(host: [0x2001, 0x0db8, 0xac10, 0xfe01, 0, 0, 0, 0], port: 12345),
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
    
    func testEncodeSECP256K1TransferOutput() throws {
        try encodeTest(
            actual: SECP256K1TransferOutput(
                amount: 12345,
                locktime: 54321,
                threshold: 1,
                addresses: [
                    Address(raw: Data(hex: "0x51025c61fbcfc078f69334f834be6dd26d55a955")!, hrp: "avax", chainId: "X"),
                    Address(raw: Data(hex: "0xc3344128e060128ede3523a24a461c8943ab0859")!, hrp: "avax", chainId: "X"),
                ]
            ),
            expected: [
                // typeID:
                0x00, 0x00, 0x00, 0x07,
                // amount:
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x30, 0x39,
                // locktime:
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xd4, 0x31,
                // threshold:
                0x00, 0x00, 0x00, 0x01,
                // number of addresses:
                0x00, 0x00, 0x00, 0x02,
                // addrs[0]:
                0x51, 0x02, 0x5c, 0x61, 0xfb, 0xcf, 0xc0, 0x78,
                0xf6, 0x93, 0x34, 0xf8, 0x34, 0xbe, 0x6d, 0xd2,
                0x6d, 0x55, 0xa9, 0x55,
                // addrs[1]:
                0xc3, 0x34, 0x41, 0x28, 0xe0, 0x60, 0x12, 0x8e,
                0xde, 0x35, 0x23, 0xa2, 0x4a, 0x46, 0x1c, 0x89,
                0x43, 0xab, 0x08, 0x59,
            ]
        )
    }
    
    func testEncodeSECP256K1MintOutput() throws {
        try encodeTest(
            actual: SECP256K1MintOutput(
                locktime: 54321,
                threshold: 1,
                addresses: [
                    Address(raw: Data(hex: "0x51025c61fbcfc078f69334f834be6dd26d55a955")!, hrp: "avax", chainId: "X"),
                    Address(raw: Data(hex: "0xc3344128e060128ede3523a24a461c8943ab0859")!, hrp: "avax", chainId: "X"),
                ]
            ),
            expected: [
                // typeID:
                0x00, 0x00, 0x00, 0x06,
                // locktime:
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xd4, 0x31,
                // threshold:
                0x00, 0x00, 0x00, 0x01,
                // number of addresses:
                0x00, 0x00, 0x00, 0x02,
                // addrs[0]:
                0x51, 0x02, 0x5c, 0x61, 0xfb, 0xcf, 0xc0, 0x78,
                0xf6, 0x93, 0x34, 0xf8, 0x34, 0xbe, 0x6d, 0xd2,
                0x6d, 0x55, 0xa9, 0x55,
                // addrs[1]:
                0xc3, 0x34, 0x41, 0x28, 0xe0, 0x60, 0x12, 0x8e,
                0xde, 0x35, 0x23, 0xa2, 0x4a, 0x46, 0x1c, 0x89,
                0x43, 0xab, 0x08, 0x59,
            ]
        )
    }
    
    func testEncodeNFTTransferOutput() throws {
        try encodeTest(
            actual: NFTTransferOutput(
                groupID: 12345,
                payload: Data(hex: "0x431100")!,
                locktime: 54321,
                threshold: 1,
                addresses: [
                    Address(raw: Data(hex: "0x51025c61fbcfc078f69334f834be6dd26d55a955")!, hrp: "avax", chainId: "X"),
                    Address(raw: Data(hex: "0xc3344128e060128ede3523a24a461c8943ab0859")!, hrp: "avax", chainId: "X"),
                ]
            ),
            expected: [
                // TypeID:
                0x00, 0x00, 0x00, 0x0b,
                // groupID:
                0x00, 0x00, 0x30, 0x39,
                // length of payload:
                0x00, 0x00, 0x00, 0x03,
                // payload:
                0x43, 0x11, 0x00,
                // locktime:
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xd4, 0x31,
                // threshold:
                0x00, 0x00, 0x00, 0x01,
                // number of addresses:
                0x00, 0x00, 0x00, 0x02,
                // addrs[0]:
                0x51, 0x02, 0x5c, 0x61, 0xfb, 0xcf, 0xc0, 0x78,
                0xf6, 0x93, 0x34, 0xf8, 0x34, 0xbe, 0x6d, 0xd2,
                0x6d, 0x55, 0xa9, 0x55,
                // addrs[1]:
                0xc3, 0x34, 0x41, 0x28, 0xe0, 0x60, 0x12, 0x8e,
                0xde, 0x35, 0x23, 0xa2, 0x4a, 0x46, 0x1c, 0x89,
                0x43, 0xab, 0x08, 0x59,
            ]
        )
    }
    
    func testEncodeNFTMintOutput() throws {
        try encodeTest(
            actual: NFTMintOutput(
                groupID: 12345,
                locktime: 54321,
                threshold: 1,
                addresses: [
                    Address(raw: Data(hex: "0x51025c61fbcfc078f69334f834be6dd26d55a955")!, hrp: "avax", chainId: "X"),
                    Address(raw: Data(hex: "0xc3344128e060128ede3523a24a461c8943ab0859")!, hrp: "avax", chainId: "X"),
                ]
            ),
            expected: [
                // TypeID
                0x00, 0x00, 0x00, 0x0a,
                // groupID:
                0x00, 0x00, 0x30, 0x39,
                // locktime:
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xd4, 0x31,
                // threshold:
                0x00, 0x00, 0x00, 0x01,
                // number of addresses:
                0x00, 0x00, 0x00, 0x02,
                // addrs[0]:
                0x51, 0x02, 0x5c, 0x61, 0xfb, 0xcf, 0xc0, 0x78,
                0xf6, 0x93, 0x34, 0xf8, 0x34, 0xbe, 0x6d, 0xd2,
                0x6d, 0x55, 0xa9, 0x55,
                // addrs[1]:
                0xc3, 0x34, 0x41, 0x28, 0xe0, 0x60, 0x12, 0x8e,
                0xde, 0x35, 0x23, 0xa2, 0x4a, 0x46, 0x1c, 0x89,
                0x43, 0xab, 0x08, 0x59,
            ]
        )
    }
}
