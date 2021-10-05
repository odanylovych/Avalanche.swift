//
//  AddressTests.swift
//  
//
//  Created by Yehor Popovych on 10/14/20.
//

import XCTest
import Avalanche
import AvalancheKeychain

final class AddressTests: XCTestCase {
    private let testKey = "PrivateKey-r6yxM4MiGc93hZ4QxSHhixLEH5RtPjGw6Y85gzg8mgaia6HT3"
    
    func testBech32() throws {
        let address = try Address(bech: "X-avax1len9mtl469gfkcphxt4fja8jrpngrm5am3dqqf")
        print("Address", address.rawAddress as NSData)
        let bech32 = address.bech
        print("Bech32", bech32)
    }
    
    func testCorrectAvmAddress() throws {
        let keyPair = try KeyPair(key: testKey)
        let address = keyPair.address(hrp: "fuji", chainId: "X")
        XCTAssertEqual(address.bech, "X-fuji1np2h3agqvgxc29sqfh0dy2nvmedus0sa44ktlr")
    }
    
    func testCorrectEvmAddress() throws {
        let keyPair = try KeyPair(key: testKey)
        let address = keyPair.ethAddress
        XCTAssertEqual(address.hex(), "0x506433b9338e2a5706e3c0d6bce041d30688935f")
    }
}
