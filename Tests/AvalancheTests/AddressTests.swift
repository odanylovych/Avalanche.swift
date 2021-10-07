//
//  AddressTests.swift
//  
//
//  Created by Yehor Popovych on 10/14/20.
//

import XCTest
import Avalanche
import UncommonCrypto

final class AddressTests: XCTestCase {
    private var chainId = "X"
    private var hrp = "tests"
    private let pubKey = Data(hex: "023a5375e93598e811e9350895bd212a1581d1ef900400201d14abc3008ff9bc01")!
    
    func testBech32() throws {
        let address = try Address(bech: "X-avax1len9mtl469gfkcphxt4fja8jrpngrm5am3dqqf")
        print("Address", address.rawAddress as NSData)
        let bech32 = address.bech
        print("Bech32", bech32)
    }

    func testCorrectAvmAddress() throws {
        let address = try Address(pubKey: pubKey, hrp: "fuji", chainId: "X")
        XCTAssertEqual(address.bech, "X-fuji1np2h3agqvgxc29sqfh0dy2nvmedus0sa44ktlr")
    }

    func testCorrectEvmAddress() throws {
        let address = try EthAddress(pubKey: pubKey)
        XCTAssertEqual(address.hex(), "0x506433b9338e2a5706e3c0d6bce041d30688935f")
    }
    
    func testVerifyMessage1() throws {
        let publicKey = Data(hex: "0x033fad3644deb20d7a210d12757092312451c112d04773cee2699fbb59dc8bb2ef")!
        let address = try Address(pubKey: publicKey, hrp: hrp, chainId: chainId)
        let message = Data(SHA2.hash(type: .sha256, bytes: Array(Data(hex: "0x09090909")!)))
        let signature = Signature(hex: "0x03f5fccca73bf0ea0ad643133c593ed3a2a69bf9d95a0c218269c0f4a07b91fc53e29ad72a3e279c8966cccfe7ae988a94d93b23d5c5516676ac57ddab319abb01")!
        assert(address.verify(message: message, signature: signature))
    }
    
    func testVerifyMessage2() throws {
        let publicKey = Data(hex: "0x02486553b276cfe7abf0efbcd8d173e55db9c03da020c33d0b219df24124da18ee")!
        let address = try Address(pubKey: publicKey, hrp: hrp, chainId: chainId)
        let message = Data(SHA2.hash(type: .sha256, bytes: Array(Data(hex: "0x09090909")!)))
        let signature = Signature(hex: "0x8ecd7d9b2613c8eabedb00333d0ae187c39a521e9631cbccf16cd14991fe5b221c9983d23583d397f3e7e377a6825c1caa5ff8b43c5863342441c48c2173119b01")!
        assert(address.verify(message: message, signature: signature))
    }
    
    func testVerifyMessage3() throws {
        let publicKey = Data(hex: "0x031475b91d4fcf52979f1cf107f058088cc2bea6edd51915790f27185a7586e2f2")!
        let address = try Address(pubKey: publicKey, hrp: hrp, chainId: chainId)
        let message = Data(SHA2.hash(type: .sha256, bytes: Array(Data(hex: "0x09090909")!)))
        let signature = Signature(hex: "0xbe9fb13be75791778ea1081820f9d25d808d0714a92880a7144a0f9809961b43079576349b255399f5339550db7f5fec4b989e3364a5ffb0aca09e5ad72e92af00")!
        assert(address.verify(message: message, signature: signature))
    }
}
