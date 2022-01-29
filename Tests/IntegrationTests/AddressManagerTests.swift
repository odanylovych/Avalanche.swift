//
//  AddressManagerTests.swift
//  
//
//  Created by Ostap Danylovych on 26.01.2022.
//

import Foundation
import XCTest
import Avalanche

final class AddressManagerTests: XCTestCase {
    private var avalanche: AvalancheCore!
    private var _manager: AvalancheAddressManager?
    
    override func setUp() {
        super.setUp()
        avalanche = Avalanche(url: TestEnvironment.url, network: TestEnvironment.network)
    }
    
    private var api: AvalancheXChainApi {
        avalanche.xChain
    }
    
    private var manager: AvalancheAddressManager {
        if _manager == nil {
            _manager = avalanche.settings.addressManagerProvider.manager(ava: avalanche)!
        }
        return _manager!
    }
    
    func testFetch() throws {
        let fetchSuccessful = expectation(description: "Fetch successful")
        let account = try! Account(pubKey: TestEnvironment.instance.publicKey,
                                   chainCode: TestEnvironment.instance.chainCode,
                                   path: try! Bip32Path.prefixAvalanche.appending(0, hard: true))
        let testAddresses = (0..<45).map {
            try! account.derive(index: $0, change: false, hrp: api.hrp, chainId: api.info.chainId).address
        } + (0..<4).map {
            try! account.derive(index: $0, change: true, hrp: api.hrp, chainId: api.info.chainId).address
        }
        let signatureProvider = SignatureProviderMock()
        signatureProvider.accountsMock = { type, cb in
            precondition(type == .both)
            cb(.success((avalanche: [account], ethereum: [])))
        }
        avalanche.signatureProvider = signatureProvider
        manager.fetch(avm: api) { res in
            try! res.get()
            let addresses = try! self.manager.get(avm: self.api, cached: account)
            XCTAssertEqual(Set(addresses), Set(testAddresses))
            fetchSuccessful.fulfill()
        }
        wait(for: [fetchSuccessful], timeout: 10)
    }
}
