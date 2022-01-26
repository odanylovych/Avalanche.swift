//
//  AddressManagerTests.swift
//  
//
//  Created by Ostap Danylovych on 25.11.2021.
//

import Foundation
import XCTest
import Avalanche
import web3swift

final class AddressManagerTests: XCTestCase {
    private var avalanche: AvalancheCore!
    private var api: AvalancheVMApiMock!
    
    private var testAvalancheAccount: Account!
    private var testExtendedAvalancheAddress: ExtendedAddress!
    private var testAvalancheAddress: Address!
    private var testEthereumAccount: EthAccount!
    private var testEthereumAddress: EthereumAddress!
    private var testAccounts: AvalancheSignatureProviderAccounts!
    private var testUtxo: UTXO!
    
    override func setUp() {
        super.setUp()
        avalanche = AvalancheCoreMock(utxoProvider: utxoProvider)
        api = AvalancheVMApiMock(avalanche: avalanche)
        testAvalancheAccount = try! Account(
            pubKey: Data(hex: "0x02ccbf163222a621523a477389b2b6318b9c43b424bdf4b74340e9b45443cc0506")!,
            chainCode: Data(count: 32),
            path: try! Bip32Path.prefixAvalanche.appending(0, hard: true)
        )
        testExtendedAvalancheAddress = try! testAvalancheAccount.derive(
            index: 0,
            change: false,
            hrp: api.hrp,
            chainId: api.info.chainId
        )
        testAvalancheAddress = testExtendedAvalancheAddress.address
        testEthereumAccount = try! EthAccount(
            pubKey: Data(hex: "0x037f3690f110231e11a42d2b71f3553e751a1268a1a21ecd4b83f9f6b420af4ad5")!,
            path: try! Bip32Path.prefixEthereum
                .appending(0, hard: true)
                .appending(0, hard: false)
                .appending(0, hard: false)
        )
        testEthereumAddress = testEthereumAccount.address
        testAccounts = (
            avalanche: [testAvalancheAccount],
            ethereum: [testEthereumAccount]
        )
        testUtxo = UTXO(
            transactionID: TransactionID(data: Data(count: TransactionID.size))!,
            utxoIndex: 1,
            assetID: AssetID(data: Data(count: AssetID.size))!,
            output: try! SECP256K1TransferOutput(
                amount: 1,
                locktime: Date(timeIntervalSince1970: 0),
                threshold: 0,
                addresses: [testAvalancheAddress]
            )
        )
    }
    
    private var signer: AvalancheSignatureProvider {
        let signer = SignatureProviderMock()
        signer.accountsMock = { type, cb in
            guard type == .both else {
                XCTFail("accounts")
                return
            }
            cb(.success(self.testAccounts))
        }
        return signer
    }
    
    private var utxoProvider: AvalancheUtxoProvider {
        let utxoProvider = UtxoProviderMock()
        utxoProvider.utxosAddressesMock = { api, addresses in
            let utxos = addresses.contains(self.testAvalancheAddress) ? [self.testUtxo!] : []
            return UtxoProviderMock.IteratorMock(nextMock: { limit, sourceChain, result in
                result(.success((utxos, nil)))
            })
        }
        return utxoProvider
    }
    
    func testStart() throws {
        let addressManager = AvalancheDefaultAddressManager(signer: signer)
        assert(addressManager.avalanche !== avalanche)
        addressManager.start(avalanche: avalanche)
        assert(addressManager.avalanche === avalanche)
    }

    func testAccountsMethod() throws {
        let success = expectation(description: "success")
        let addressManager = AvalancheDefaultAddressManager(signer: signer)
        addressManager.start(avalanche: avalanche)
        addressManager.accounts(type: .both) { res in
            let accounts = try! res.get()
            XCTAssertEqual(accounts.avalanche, self.testAccounts.avalanche)
            XCTAssertEqual(accounts.ethereum, self.testAccounts.ethereum)
            success.fulfill()
        }
        wait(for: [success], timeout: 10)
    }

    func testNew() throws {
        let success = expectation(description: "success")
        let addressManager = AvalancheDefaultAddressManager(signer: signer)
        addressManager.start(avalanche: avalanche)
        addressManager.fetch(avm: api) { res in
            try! res.get()
            let addresses = try! addressManager.new(avm: self.api, for: self.testAvalancheAccount, change: false, count: 1)
            let newAddress = try! self.testAvalancheAccount.derive(
                index: 1,
                change: false,
                hrp: self.api.hrp,
                chainId: self.api.info.chainId
            ).address
            XCTAssertEqual(addresses, [newAddress])
            success.fulfill()
        }
        wait(for: [success], timeout: 10)
    }
    
    func testGetCached() throws {
        let success = expectation(description: "success")
        let addressManager = AvalancheDefaultAddressManager(signer: signer)
        addressManager.start(avalanche: avalanche)
        XCTAssertThrowsError(try addressManager.get(avm: self.api, cached: self.testAvalancheAccount))
        addressManager.fetch(avm: api) { res in
            try! res.get()
            let addresses = try! addressManager.get(avm: self.api, cached: self.testAvalancheAccount)
            XCTAssertEqual(addresses, [self.testAvalancheAddress])
            success.fulfill()
        }
        wait(for: [success], timeout: 10)
    }
    
    func testGetForAccount() throws {
        let success = expectation(description: "success")
        let addressManager = AvalancheDefaultAddressManager(signer: signer)
        addressManager.start(avalanche: avalanche)
        addressManager.get(avm: self.api, for: self.testAvalancheAccount) { res in
            let addresses = try! res.get()
            XCTAssertEqual(addresses, [self.testAvalancheAddress])
            success.fulfill()
        }
        wait(for: [success], timeout: 10)
    }
    
    func testFetch() throws {
        let testAddresses = (0..<50).map { index in
            try! testAvalancheAccount.derive(
                index: index,
                change: false,
                hrp: api.hrp,
                chainId: api.info.chainId
            ).address
        }
        let addressUtxo = { address in
            (address, UTXO(
                transactionID: TransactionID(data: Data(count: TransactionID.size))!,
                utxoIndex: 1,
                assetID: AssetID(data: Data(count: AssetID.size))!,
                output: try! SECP256K1TransferOutput(
                    amount: 1,
                    locktime: Date(timeIntervalSince1970: 0),
                    threshold: 0,
                    addresses: [address]
                )
            ))
        }
        let addressUtxoMap = Dictionary(uniqueKeysWithValues: [
            addressUtxo(testAddresses[0]),
            addressUtxo(testAddresses[5]),
            addressUtxo(testAddresses[20]),
            addressUtxo(testAddresses[49])
        ])
        let utxoProvider = UtxoProviderMock()
        utxoProvider.utxosAddressesMock = { api, addresses in
            let utxos = addresses.compactMap { addressUtxoMap[$0] }
            return UtxoProviderMock.IteratorMock(nextMock: { limit, sourceChain, result in
                result(.success((utxos, nil)))
            })
        }
        avalanche.utxoProvider = utxoProvider
        let success = expectation(description: "success")
        let addressManager = AvalancheDefaultAddressManager(signer: signer)
        addressManager.start(avalanche: avalanche)
        addressManager.fetch(avm: api, for: [self.testAvalancheAccount]) { res in
            try! res.get()
            let addresses = try! addressManager.get(avm: self.api, cached: self.testAvalancheAccount)
            XCTAssertEqual(Set(addresses), Set(testAddresses.prefix(21)))
            success.fulfill()
        }
        wait(for: [success], timeout: 10)
    }
    
    func testFetchForAccounts() throws {
        let success = expectation(description: "success")
        let addressManager = AvalancheDefaultAddressManager(signer: signer)
        addressManager.start(avalanche: avalanche)
        addressManager.fetch(avm: api, for: [self.testAvalancheAccount]) { res in
            try! res.get()
            let accounts = addressManager.fetchedAccounts()
            XCTAssertEqual(accounts.avalanche, [])
            XCTAssertEqual(accounts.ethereum, [])
            let addresses = try! addressManager.get(avm: self.api, cached: self.testAvalancheAccount)
            XCTAssertEqual(addresses, [self.testAvalancheAddress])
            success.fulfill()
        }
        wait(for: [success], timeout: 10)
    }
    
    func testFetchedAccounts() throws {
        let success = expectation(description: "success")
        let addressManager = AvalancheDefaultAddressManager(signer: signer)
        addressManager.start(avalanche: avalanche)
        let accounts = addressManager.fetchedAccounts()
        XCTAssertEqual(accounts.avalanche, [])
        XCTAssertEqual(accounts.ethereum, [])
        addressManager.fetch(avm: api) { res in
            try! res.get()
            let accounts = addressManager.fetchedAccounts()
            XCTAssertEqual(accounts.avalanche, self.testAccounts.avalanche)
            XCTAssertEqual(accounts.ethereum, self.testAccounts.ethereum)
            success.fulfill()
        }
        wait(for: [success], timeout: 10)
    }
    
    func testExtendedAvm() throws {
        let success = expectation(description: "success")
        let addressManager = AvalancheDefaultAddressManager(signer: signer)
        addressManager.start(avalanche: avalanche)
        addressManager.fetch(avm: api) { res in
            try! res.get()
            let extended = try! addressManager.extended(avm: [self.testAvalancheAddress])
            XCTAssertEqual(extended, [self.testExtendedAvalancheAddress])
            success.fulfill()
        }
        wait(for: [success], timeout: 10)
    }
    
    func testExtendedEth() throws {
        let success = expectation(description: "success")
        let addressManager = AvalancheDefaultAddressManager(signer: signer)
        addressManager.start(avalanche: avalanche)
        addressManager.fetch(avm: api) { res in
            try! res.get()
            let extended = try! addressManager.extended(eth: [self.testEthereumAddress])
            XCTAssertEqual(extended, [self.testEthereumAccount])
            success.fulfill()
        }
        wait(for: [success], timeout: 10)
    }
}
