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
        let encoded = Array(try AEncoder().encode(actual).output)
        XCTAssertEqual(encoded, expected)
    }
    
    private func encodeFixedTest(actual: AvalancheFixedEncodable, expected: [UInt8], size: Int) throws {
        let encoded = Array(try AEncoder().encode(actual, size: size).output)
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
    
    func testEncodeTransferableOutput() throws {
        try encodeTest(
            actual: TransferableOutput(
                assetId: AssetID(data: Data(hex: "0x000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f")!)!,
                output: SECP256K1TransferOutput(
                    amount: 12345,
                    locktime: 54321,
                    threshold: 1,
                    addresses: [
                        Address(raw: Data(hex: "0x51025c61fbcfc078f69334f834be6dd26d55a955")!, hrp: "avax", chainId: "X"),
                        Address(raw: Data(hex: "0xc3344128e060128ede3523a24a461c8943ab0859")!, hrp: "avax", chainId: "X"),
                    ]
                )
            ),
            expected: [
                // assetID:
                0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
                0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
                0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
                0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f,
                // output:
                0x00, 0x00, 0x00, 0x07, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x30, 0x39, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0xd4, 0x31, 0x00, 0x00, 0x00, 0x01,
                0x00, 0x00, 0x00, 0x02, 0x51, 0x02, 0x5c, 0x61,
                0xfb, 0xcf, 0xc0, 0x78, 0xf6, 0x93, 0x34, 0xf8,
                0x34, 0xbe, 0x6d, 0xd2, 0x6d, 0x55, 0xa9, 0x55,
                0xc3, 0x34, 0x41, 0x28, 0xe0, 0x60, 0x12, 0x8e,
                0xde, 0x35, 0x23, 0xa2, 0x4a, 0x46, 0x1c, 0x89,
                0x43, 0xab, 0x08, 0x59,
            ]
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
    
    func testEncodeTransferableInput() throws {
        try encodeTest(
            actual: TransferableInput(
                transactionID: TransactionID(data: Data(hex: "0xf1e1d1c1b1a191817161514131211101f0e0d0c0b0a090807060504030201000")!)!,
                utxoIndex: 5,
                assetID: AssetID(data: Data(hex: "0x000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f")!)!,
                input: SECP256K1TransferInput(
                    amount: 123456789,
                    addressIndices: [3, 7]
                )
            ),
            expected: [
                // txID:
                0xf1, 0xe1, 0xd1, 0xc1, 0xb1, 0xa1, 0x91, 0x81,
                0x71, 0x61, 0x51, 0x41, 0x31, 0x21, 0x11, 0x01,
                0xf0, 0xe0, 0xd0, 0xc0, 0xb0, 0xa0, 0x90, 0x80,
                0x70, 0x60, 0x50, 0x40, 0x30, 0x20, 0x10, 0x00,
                // utxoIndex:
                0x00, 0x00, 0x00, 0x05,
                // assetID:
                0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
                0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
                0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
                0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f,
                // input:
                0x00, 0x00, 0x00, 0x05, 0x00, 0x00, 0x00, 0x00,
                0x07, 0x5b, 0xcd, 0x15, 0x00, 0x00, 0x00, 0x02,
                0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x07
            ]
        )
    }
    
    func testEncodeSECP256K1TransferInput() throws {
        try encodeTest(
            actual: SECP256K1TransferInput(
                amount: 123456789,
                addressIndices: [3, 7]
            ),
            expected: [
                // type id:
                0x00, 0x00, 0x00, 0x05,
                // amount:
                0x00, 0x00, 0x00, 0x00, 0x07, 0x5b, 0xcd, 0x15,
                // length:
                0x00, 0x00, 0x00, 0x02,
                // sig[0]
                0x00, 0x00, 0x00, 0x03,
                // sig[1]
                0x00, 0x00, 0x00, 0x07,
            ]
        )
    }
    
    func testEncodeSECP256K1MintOperation() throws {
        try encodeTest(
            actual: SECP256K1MintOperation(
                addressIndices: [0x00000003, 0x00000007],
                mintOutput: SECP256K1MintOutput(
                    locktime: 54321,
                    threshold: 1,
                    addresses: [
                        Address(raw: Data(hex: "0x51025c61fbcfc078f69334f834be6dd26d55a955")!, hrp: "avax", chainId: "X"),
                        Address(raw: Data(hex: "0xc3344128e060128ede3523a24a461c8943ab0859")!, hrp: "avax", chainId: "X"),
                    ]
                ),
                transferOutput: SECP256K1TransferOutput(
                    amount: 12345,
                    locktime: 54321,
                    threshold: 1,
                    addresses: [
                        Address(raw: Data(hex: "0x51025c61fbcfc078f69334f834be6dd26d55a955")!, hrp: "avax", chainId: "X"),
                        Address(raw: Data(hex: "0xc3344128e060128ede3523a24a461c8943ab0859")!, hrp: "avax", chainId: "X"),
                    ]
                )
            ),
            expected: [
                // typeID
                0x00, 0x00, 0x00, 0x08,
                // number of address_indices:
                0x00, 0x00, 0x00, 0x02,
                // address_indices[0]:
                0x00, 0x00, 0x00, 0x03,
                // address_indices[1]:
                0x00, 0x00, 0x00, 0x07,
                // mint output
                0x00, 0x00, 0x00, 0x06, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0xd4, 0x31, 0x00, 0x00, 0x00, 0x01,
                0x00, 0x00, 0x00, 0x02, 0x51, 0x02, 0x5c, 0x61,
                0xfb, 0xcf, 0xc0, 0x78, 0xf6, 0x93, 0x34, 0xf8,
                0x34, 0xbe, 0x6d, 0xd2, 0x6d, 0x55, 0xa9, 0x55,
                0xc3, 0x34, 0x41, 0x28, 0xe0, 0x60, 0x12, 0x8e,
                0xde, 0x35, 0x23, 0xa2, 0x4a, 0x46, 0x1c, 0x89,
                0x43, 0xab, 0x08, 0x59,
                // transfer output
                0x00, 0x00, 0x00, 0x07, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x30, 0x39, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0xd4, 0x31, 0x00, 0x00, 0x00, 0x01,
                0x00, 0x00, 0x00, 0x02, 0x51, 0x02, 0x5c, 0x61,
                0xfb, 0xcf, 0xc0, 0x78, 0xf6, 0x93, 0x34, 0xf8,
                0x34, 0xbe, 0x6d, 0xd2, 0x6d, 0x55, 0xa9, 0x55,
                0xc3, 0x34, 0x41, 0x28, 0xe0, 0x60, 0x12, 0x8e,
                0xde, 0x35, 0x23, 0xa2, 0x4a, 0x46, 0x1c, 0x89,
                0x43, 0xab, 0x08, 0x59,
            ]
        )
    }
    
    func testEncodeNFTMintOp() throws {
        try encodeTest(
            actual: NFTMintOperation(
                addressIndices: [0x00000003, 0x00000007],
                groupID: 12345,
                payload: Data(hex: "0x431100")!,
                outputs: [
                    NFTMintOperationOutput(
                        locktime: 54321,
                        threshold: 1,
                        addresses: [
                            Address(
                                raw: Data(hex: "0xc3344128e060128ede3523a24a461c8943ab0859")!,
                                hrp: "avax",
                                chainId: "X"
                            ),
                        ]
                    )
                ]
            ),
            expected: [
                // Type ID
                0x00, 0x00, 0x00, 0x0c,
                // number of address indices:
                0x00, 0x00, 0x00, 0x02,
                // address index 0:
                0x00, 0x00, 0x00, 0x03,
                // address index 1:
                0x00, 0x00, 0x00, 0x07,
                // groupID:
                0x00, 0x00, 0x30, 0x39,
                // length of payload:
                0x00, 0x00, 0x00, 0x03,
                // payload:
                0x43, 0x11, 0x00,
                // number of outputs:
                0x00, 0x00, 0x00, 0x01,
                // outputs[0]
                // locktime:
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xd4, 0x31,
                // threshold:
                0x00, 0x00, 0x00, 0x01,
                // number of addresses:
                0x00, 0x00, 0x00, 0x01,
                // addrs[0]:
                0xc3, 0x34, 0x41, 0x28, 0xe0, 0x60, 0x12, 0x8e,
                0xde, 0x35, 0x23, 0xa2, 0x4a, 0x46, 0x1c, 0x89,
                0x43, 0xab, 0x08, 0x59,
            ]
        )
    }
    
    func testEncodeNFTTransferOp() throws {
        try encodeTest(
            actual: NFTTransferOperation(
                addressIndices: [0x00000007, 0x00000003],
                nftTransferOutput: NFTTransferOperationOutput(
                    groupID: 12345,
                    payload: Data(hex: "0x431100")!,
                    locktime: 54321,
                    threshold: 1,
                    addresses: [
                        Address(
                            raw: Data(hex: "0x51025c61fbcfc078f69334f834be6dd26d55a955")!,
                            hrp: "avax",
                            chainId: "X"
                        ),
                        Address(
                            raw: Data(hex: "0xc3344128e060128ede3523a24a461c8943ab0859")!,
                            hrp: "avax",
                            chainId: "X"
                        ),
                    ]
                )
            ),
            expected: [
                // Type ID
                0x00, 0x00, 0x00, 0x0d,
                // number of address indices:
                0x00, 0x00, 0x00, 0x02,
                // address index 0:
                0x00, 0x00, 0x00, 0x07,
                // address index 1:
                0x00, 0x00, 0x00, 0x03,
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
    
    func testEncodeTransferableOp() throws {
        try encodeTest(
            actual: TransferableOperation(
                assetID: AssetID(data: Data(hex: "0x000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f")!)!,
                utxoIDs: [
                    UTXOID(
                        transactionID: TransactionID(
                            data: Data(hex: "0xf1e1d1c1b1a191817161514131211101f0e0d0c0b0a090807060504030201000")!
                        )!,
                        utxoIndex: 5
                    )
                ],
                transferOperation: NFTTransferOperation(
                    addressIndices: [0x00000007, 0x00000003],
                    nftTransferOutput: NFTTransferOperationOutput(
                        groupID: 12345,
                        payload: Data(hex: "0x431100")!,
                        locktime: 54321,
                        threshold: 1,
                        addresses: [
                            Address(
                                raw: Data(hex: "0x51025c61fbcfc078f69334f834be6dd26d55a955")!,
                                hrp: "avax",
                                chainId: "X"
                            ),
                            Address(
                                raw: Data(hex: "0xc3344128e060128ede3523a24a461c8943ab0859")!,
                                hrp: "avax",
                                chainId: "X"
                            ),
                        ]
                    )
                )
            ),
            expected: [
                // assetID:
                0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
                0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
                0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
                0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f,
                // number of utxoIDs:
                0x00, 0x00, 0x00, 0x01,
                // txID:
                0xf1, 0xe1, 0xd1, 0xc1, 0xb1, 0xa1, 0x91, 0x81,
                0x71, 0x61, 0x51, 0x41, 0x31, 0x21, 0x11, 0x01,
                0xf0, 0xe0, 0xd0, 0xc0, 0xb0, 0xa0, 0x90, 0x80,
                0x70, 0x60, 0x50, 0x40, 0x30, 0x20, 0x10, 0x00,
                // utxoIndex:
                0x00, 0x00, 0x00, 0x05,
                // op:
                0x00, 0x00, 0x00, 0x0d, 0x00, 0x00, 0x00, 0x02,
                0x00, 0x00, 0x00, 0x07, 0x00, 0x00, 0x00, 0x03,
                0x00, 0x00, 0x30, 0x39, 0x00, 0x00, 0x00, 0x03,
                0x43, 0x11, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0xd4, 0x31, 0x00, 0x00, 0x00, 0x01, 0x00,
                0x00, 0x00, 0x02, 0x51, 0x02, 0x5c, 0x61, 0xfb,
                0xcf, 0xc0, 0x78, 0xf6, 0x93, 0x34, 0xf8, 0x34,
                0xbe, 0x6d, 0xd2, 0x6d, 0x55, 0xa9, 0x55, 0xc3,
                0x34, 0x41, 0x28, 0xe0, 0x60, 0x12, 0x8e, 0xde,
                0x35, 0x23, 0xa2, 0x4a, 0x46, 0x1c, 0x89, 0x43,
                0xab, 0x08, 0x59,
            ]
        )
    }
    
}
