//
//  Base58Tests.swift
//  
//
//  Created by Yehor Popovych on 31.08.2021.
//

import XCTest
@testable import Avalanche

final class Base58SwiftTests: XCTestCase {
    /// Tuples of arbitrary strings that are mapped to valid Base58 encodings.
    private let validStringDecodedToEncodedTuples = [
        ("", ""),
        (" ", "Z"),
        ("-", "n"),
        ("0", "q"),
        ("1", "r"),
        ("-1", "4SU"),
        ("11", "4k8"),
        ("abc", "ZiCa"),
        ("1234598760", "3mJr7AoUXx2Wqd"),
        ("abcdefghijklmnopqrstuvwxyz", "3yxU3u1igY8WkgtjK92fbJQCd4BZiiT1v25f"),
        ("00000000000000000000000000000000000000000000000000000000000000",
         "3sN2THZeE9Eh9eYrwkvZqNstbHGvrxSAM7gXUXvyFQP8XvQLUqNCS27icwUeDT7ckHm4FUHM2mTVh1vbLmk7y")
    ]
    
    /// Tuples of invalid strings.
    private let invalidStrings = [
        "0",
        "O",
        "I",
        "l",
        "3mJr0",
        "O3yxU",
        "3sNI",
        "4kl8",
        "0OIl",
        "!@#$%^&*()-_=+~`"
    ]
    
    public func testBase58EncodingForValidStrings() {
        for (decoded, encoded) in validStringDecodedToEncodedTuples {
            let bytes = Data(decoded.utf8)
            let result = Algos.Base58.b58(data: bytes)
            XCTAssertEqual(result, encoded)
        }
    }
    
    public func testBase58DecodingForValidStrings() {
        for (decoded, encoded) in validStringDecodedToEncodedTuples {
            guard let bytes = Algos.Base58.from(b58: encoded) else {
                XCTFail()
                return
            }
            let result = String(bytes: bytes, encoding: .utf8)
            XCTAssertEqual(result, decoded)
        }
    }
    
    public func testBase58DecodingForInvalidStrings() {
        for invalidString in invalidStrings {
            let result = Algos.Base58.from(b58: invalidString)
            XCTAssertNil(result)
        }
    }
    
    public func testBase58CheckEncoding() {
        let inputData: [UInt8] = [
            6, 161, 159, 136, 34, 110, 33, 238, 14, 79, 14, 218, 133, 13, 109, 40, 194, 236, 153, 44, 61, 157, 254
        ]
        let expectedOutput = "tz1Y3qqTg9HdrzZGbEjiCPmwuZ7fWVsLk6x9"
        let actualOutput = Algos.Base58.cb58(data: Data(inputData))
        XCTAssertEqual(actualOutput, expectedOutput)
    }
    
    public func testBase58CheckDecoding() {
        let inputString = "tz1Y3qqTg9HdrzZGbEjiCPmwuZ7fWVsLk6x9"
        let expectedOutputData: [UInt8] = [
            6, 161, 159, 136, 34, 110, 33, 238, 14, 79, 14, 218, 133, 13, 109, 40, 194, 236, 153, 44, 61, 157, 254
        ]
        
        guard let actualOutput = Algos.Base58.from(cb58: inputString) else {
            XCTFail()
            return
        }
        XCTAssertEqual(actualOutput.bytes, expectedOutputData)
    }
    
    public func testBase58CheckDecodingWithInvalidCharacters() {
        XCTAssertNil(Algos.Base58.from(cb58: "0oO1lL"))
    }
    
    public func testBase58CheckDecodingWithInvalidChecksum() {
        XCTAssertNil(Algos.Base58.from(cb58: "tz1Y3qqTg9HdrzZGbEjiCPmwuZ7fWVxpPtrW"))
    }
    
    public func testBase58CheckDecodingEmptyBytes() {
        let inputString = "11111111111111111111111111111111LpoYY"
        let expected = Data(repeating: 0, count: 32)
        guard let actualOutput = Algos.Base58.from(cb58: inputString) else {
            XCTFail()
            return
        }
        XCTAssertEqual(actualOutput, expected)
    }
    
    public func testBase58CheckEncodingEmptyBytes() {
        let inputData = Data(repeating: 0, count: 32)
        let expected = "11111111111111111111111111111111LpoYY"
        let actualOutput = Algos.Base58.cb58(data: inputData)
        XCTAssertEqual(actualOutput, expected)
    }
}

