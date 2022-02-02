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
    let seed: Data
    let publicKey: Data
    let chainCode: Data
    
    static var instance: Self {
        let env = ProcessInfo.processInfo.environment
        let seed = env["CARDANO_TEST_SEED"]!
        let publicKey = env["CARDANO_TEST_PUBLIC_KEY"]!
        let chainCode = env["CARDANO_TEST_CHAIN_CODE"]!
        return Self(
            seed: Data(hex: seed),
            publicKey: Data(hex: publicKey),
            chainCode: Data(hex: chainCode)
        )
    }
}
