//
//  XChainTests.swift
//  
//
//  Created by Ostap Danylovych on 29.01.2022.
//

import Foundation
import XCTest
import Avalanche
import AvalancheKeychain

final class XChainTests: XCTestCase {
    private var avalanche: AvalancheCore!
    private var keychain: AvalancheBip44Keychain!
    
    override func setUp() {
        super.setUp()
        avalanche = Avalanche(url: TestEnvironment.url, network: TestEnvironment.network)
        keychain = try! AvalancheBip44Keychain(seed: TestEnvironment.instance.seed)
        avalanche.signatureProvider = keychain
    }
    
    private var api: AvalancheXChainApi {
        avalanche.xChain
    }
    
    func testSendAvax() throws {
        let sent = expectation(description: "Avax sent")
        try keychain.addAvalancheAccount(index: 0)
        guard let manager = api.keychain else {
            XCTFail("Empty address manager in api")
            return
        }
        manager.fetch { res in
            try! res.get()
            let account = manager.fetchedAccounts().first!
            let addresses = try! manager.get(cached: account)
            let to = addresses.count < 100
            ? try! manager.newAddress(for: account)
            : addresses.randomElement()!
            self.api.send(avax: 10_000_000, to: to, credentials: .account(account)) { res in
                let (txID, _) = try! res.get()
                self.api.getTransaction(id: txID) { res in
                    let signed = try! res.get()
                    let transaction = signed.unsignedTransaction as? BaseTransaction
                    XCTAssertNotNil(transaction)
                    sent.fulfill()
                }
            }
        }
        wait(for: [sent], timeout: 1000)
    }
}
