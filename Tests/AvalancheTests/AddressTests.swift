//
//  AddressTests.swift
//  
//
//  Created by Yehor Popovych on 10/14/20.
//

import XCTest
import Avalanche

final class AddressTests: XCTestCase {
    func testBech32() throws {
        let address = try Address(bech: "X-avax1len9mtl469gfkcphxt4fja8jrpngrm5am3dqqf")
        
        
        
        print("Address", address.rawAddress as NSData)
        let bech32 = address.bech
        print("Bech32", bech32)
    }
}
