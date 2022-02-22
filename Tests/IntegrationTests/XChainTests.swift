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
    private typealias AsyncWaitCondition = (@escaping (Bool) -> ()) -> ()
    
    private var queue: DispatchQueue!
    private var avalanche: AvalancheCore!
    private var keychain: AvalancheBip44Keychain!
    
    override func setUp() {
        super.setUp()
        queue = DispatchQueue(label: "XChainTests.Async.Queue", target: .global())
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
    
    private static func utxosToAppear<A: AvalancheTransactionApi>(
        on chain: A,
        addresses: [Address],
        source: BlockchainID
    ) -> AsyncWaitCondition {
        { cb in
            let iterator = chain.utxoProvider.utxos(api: chain, addresses: addresses)
            iterator.next(sourceChain: source) { res in
                let utxos = try! res.get().utxos
                cb(!utxos.isEmpty)
            }
        }
    }
    
    private func asyncWait(for condition: @escaping AsyncWaitCondition, _ cb: @escaping () -> ()) {
        condition() { result in
            guard result else {
                self.queue.asyncAfter(deadline: .now() + 10) {
                    self.asyncWait(for: condition, cb)
                }
                return
            }
            cb()
        }
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
        let exported = expectation(description: "Exported to P-Chain")
        try keychain.addAvalancheAccount(index: 0)
        guard let manager = api.keychain,
              let pChainManager = pChain.keychain else {
            XCTFail("Empty address manager in api")
            return
        }
        manager.fetch { res in
            try! res.get()
            let account = manager.fetchedAccounts().first!
            pChainManager.fetch { res in
                try! res.get()
                let to = try! pChainManager.newAddress(for: account)
                self.api.getAvaxAssetID { res in
                    let assetID = try! res.get()
                    self.api.export(to: to, amount: 10_000_000, assetID: assetID, credentials: .account(account)) { res in
                        let (txID, _) = try! res.get()
                        self.api.getTransaction(id: txID) { res in
                            let signed = try! res.get()
                            let transaction = signed.unsignedTransaction as? ExportTransaction
                            XCTAssertNotNil(transaction)
                            self.api.getBlockchainID { res in
                                let source = try! res.get()
                                self.asyncWait(for: Self.utxosToAppear(on: self.pChain, addresses: [to], source: source)) {
                                    self.pChain.importAVAX(to: to,
                                                           source: source,
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
            }
        }
        wait(for: [exported], timeout: 100)
    }
    
    func testExportToCChain() throws {
        let exported = expectation(description: "Exported to C-Chain")
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
            cChainManager.accounts { res in
                let ethAccount = try! res.get().first!
                let to = try! cChainManager.get(for: ethAccount)
                self.api.getAvaxAssetID { res in
                    let assetID = try! res.get()
                    self.api.export(to: to, amount: 10_000_000, assetID: assetID, credentials: .account(account)) { res in
                        let (txID, _) = try! res.get()
                        self.api.getTransaction(id: txID) { res in
                            let signed = try! res.get()
                            let transaction = signed.unsignedTransaction as? ExportTransaction
                            XCTAssertNotNil(transaction)
                            self.api.getBlockchainID { res in
                                let source = try! res.get()
                                self.asyncWait(for: Self.utxosToAppear(on: self.cChain, addresses: [to], source: source)) {
                                    self.cChain.import(to: ethAccount.address,
                                                       sourceChain: source,
                                                       credentials: .account(ethAccount)) { res in
                                        let txID = try! res.get()
                                        print("Import Transaction: \(txID.cb58())")
                                        exported.fulfill()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        wait(for: [exported], timeout: 100)
    }
}
