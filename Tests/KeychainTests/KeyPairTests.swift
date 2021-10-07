//
//  KeyPair.swift
//  
//
//  Created by Daniel Leping on 07/01/2021.
//

import XCTest
@testable import Avalanche

#if !COCOAPODS
@testable import AvalancheKeychain
#else
@testable import Avalanche
#endif

final class KeyPairTests: XCTestCase {
    private var alias = "X"
    private var hrp = "tests"
    
    func testRepeatable1() throws {
        let keyPair = try KeyPair(
            sk: Data(hex: "0xef9bf2d4436491c153967c9709dd8e82795bdb9b5ad44ee22c2903005d1cf676")!,
            chainCode: nil
        )
        XCTAssertEqual(keyPair.publicKey.hex(), "0x033fad3644deb20d7a210d12757092312451c112d04773cee2699fbb59dc8bb2ef")
    }
    
    func testBadPrivateKey() throws {
        let badPrivateKey = "safasaf"
        XCTAssertThrowsError(try KeyPair(key: badPrivateKey))
    }
    
    func testRepeatable2() throws {
        let keyPair = try KeyPair(
            sk: Data(hex: "0x17c692d4a99d12f629d9f0ff92ec0dba15c9a83e85487b085c1a3018286995c6")!,
            chainCode: nil
        )
        XCTAssertEqual(keyPair.publicKey.hex(), "0x02486553b276cfe7abf0efbcd8d173e55db9c03da020c33d0b219df24124da18ee")
    }
    
    func testRepeatable3() throws {
        let keyPair = try KeyPair(
            sk: Data(hex: "0xd0e17d4b31380f96a42b3e9ffc4c1b2a93589a1e51d86d7edc107f602fbc7475")!,
            chainCode: nil
        )
        XCTAssertEqual(keyPair.publicKey.hex(), "0x031475b91d4fcf52979f1cf107f058088cc2bea6edd51915790f27185a7586e2f2")
    }
    
    func testCreationEmpty() throws {
        let generatedKeyPair = KeyPair.generate()
        let keyPair = try XCTUnwrap(generatedKeyPair)
        assert(!keyPair.privateString.isEmpty)
        assert(!keyPair.address(hrp: hrp, chainId: alias).rawAddress.isEmpty)
        assert(!keyPair.publicKey.isEmpty)
        assert(!keyPair.publicString.isEmpty)
    }
}
