//
//  TestEnvironment.swift
//  
//
//  Created by Ostap Danylovych on 29.01.2022.
//

import Foundation
import Avalanche

struct TestEnvironment {
    static let url = URL(string: "https://api.avax-test.network")!
    static let network: NetworkID = .test
    let publicKey: Data
    let chainCode: Data
    
    static var instance: Self {
        let env = ProcessInfo.processInfo.environment
        let publicKey = env["CARDANO_TEST_PUBLIC_KEY"]!
        let chainCode = env["CARDANO_TEST_CHAIN_CODE"]!
        return Self(
            publicKey: Data(hex: publicKey),
            chainCode: Data(hex: chainCode)
        )
    }
}
