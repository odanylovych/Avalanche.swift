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
    
    private var pChain: AvalanchePChainApi {
        avalanche.pChain
    }
    
    private var cChain: AvalancheCChainApi {
        avalanche.cChain
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
        wait(for: [sent], timeout: 100)
    }
    
    func testExportToPChain() throws {
        let exported = expectation(description: "exported")
        try keychain.addAvalancheAccount(index: 0)
        guard let manager = api.keychain,
              let pChainManager = pChain.keychain else {
            XCTFail("Empty address manager in api")
            return
        }
        manager.fetch { res in
            try! res.get()
            let account = manager.fetchedAccounts().first!
            let to = try! account.derive(index: 0,
                                         change: false,
                                         hrp: self.api.hrp,
                                         chainId: self.pChain.info.chainId).address
            self.api.getAvaxAssetID { res in
                let assetID = try! res.get()
                self.api.export(to: to, amount: 10_000_000, assetID: assetID, credentials: .account(account)) { res in
                    let (txID, _) = try! res.get()
                    self.api.getTransaction(id: txID) { res in
                        let signed = try! res.get()
                        let transaction = signed.unsignedTransaction as? ExportTransaction
                        XCTAssertNotNil(transaction)
                        let sourceChain = self.api.info.blockchainID
                        pChainManager.fetch { res in
                            try! res.get()
                            // TODO: async wait for utxos to appear on pchain
                            self.pChain.importAVAX(to: to,
                                                   source: sourceChain,
                                                   credentials: .account(account)) { res in
                                let (txID, _) = try! res.get()
                                print("Import Transaction: \(txID.cb58())")
                                exported.fulfill()
                            }
                        }
                    }
                }
            }
        }
        wait(for: [exported], timeout: 100)
    }
    
    func testExportToCChain() throws {
        let exported = expectation(description: "exported")
        try keychain.addAvalancheAccount(index: 0)
        try keychain.addEthereumAccount(index: 0)
        guard let manager = api.keychain,
              let cChainManager = cChain.keychain else {
            XCTFail("Empty address manager in api")
            return
        }
        manager.fetch { res in
            try! res.get()
            let account = manager.fetchedAccounts().first!
            let to = try! account.derive(index: 0,
                                         change: false,
                                         hrp: self.api.hrp,
                                         chainId: self.cChain.info.chainId).address
            self.api.getAvaxAssetID { res in
                let assetID = try! res.get()
                self.api.export(to: to, amount: 10_000_000, assetID: assetID, credentials: .account(account)) { res in
                    let (txID, _) = try! res.get()
                    self.api.getTransaction(id: txID) { res in
                        let signed = try! res.get()
                        let transaction = signed.unsignedTransaction as? ExportTransaction
                        XCTAssertNotNil(transaction)
                        let sourceChain = self.api.info.blockchainID
                        cChainManager.fetch { res in
                            try! res.get()
                            let eth = cChainManager.manager.fetchedAccounts().ethereum.first!
                            // TODO: async wait for utxos to appear on cchain
                            self.cChain.import(to: eth.address,
                                               sourceChain: sourceChain,
                                               credentials: .account(account)) { res in
                                let txID = try! res.get()
                                print("Import Transaction: \(txID.cb58())")
                                exported.fulfill()
                            }
                        }
                    }
                }
            }
        }
        wait(for: [exported], timeout: 100)
    }
}
