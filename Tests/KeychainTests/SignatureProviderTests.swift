//
//  SignatureProviderTests.swift
//  
//
//  Created by Ostap Danylovych on 17.12.2021.
//

import Foundation
import XCTest
import Avalanche
import AvalancheKeychain
import AvalancheTests

final class SignatureProviderTests: XCTestCase {
    private var signer: AvalancheBip44Keychain!
    private var avalancheAccount: Account!
    private var avalancheAddress: ExtendedAddress!
    private var avalancheKeyPair: KeyPair!
    private var ethereumAccount: EthAccount!
    private var ethereumKeyPair: KeyPair!
    
    override func setUp() {
        super.setUp()
        let root = try! KeyPair(
            sk: Data(hex: "0xef9bf2d4436491c153967c9709dd8e82795bdb9b5ad44ee22c2903005d1cf676")!,
            chainCode: Data(count: 32)
        )
        signer = try! AvalancheBip44Keychain(root: root)
        let index: UInt32 = 0
        var b44 = Bip32Path.prefixAvalanche
        avalancheKeyPair = try! root
            .derive(index: b44.path[0], hard: true)
            .derive(index: b44.path[1], hard: true)
            .derive(index: index, hard: true)
        var path = try! Bip32Path.prefixAvalanche.appending(index, hard: true)
        avalancheAccount = try! Account(
            pubKey: avalancheKeyPair.publicKey,
            chainCode: avalancheKeyPair.chainCode!,
            path: path
        )
        avalancheKeyPair = try! avalancheKeyPair
            .derive(index: 0, hard: false)
            .derive(index: 0, hard: false)
        avalancheAddress = try! avalancheAccount.derive(
            index: 0,
            change: false,
            hrp: "hrp",
            chainId: "chainId"
        )
        b44 = Bip32Path.prefixEthereum
        ethereumKeyPair = try! root
            .derive(index: b44.path[0], hard: true)
            .derive(index: b44.path[1], hard: true)
            .derive(index: index, hard: true)
            .derive(index: 0, hard: false)
            .derive(index: 0, hard: false)
        path = try! Bip32Path.prefixEthereum
            .appending(index, hard: true)
            .appending(0, hard: false)
            .appending(0, hard: false)
        ethereumAccount = try! EthAccount(pubKey: ethereumKeyPair.publicKey, path: path)
        try! signer.addAvalancheAccount(index: index)
        try! signer.addEthereumAccount(index: index)
    }
    
    func testAccounts() throws {
        let avalancheOnly = expectation(description: "avalancheOnly")
        let ethereumOnly = expectation(description: "ethereumOnly")
        let both = expectation(description: "both")
        signer.accounts(type: .avalancheOnly) { res in
            let accounts = try! res.get()
            XCTAssertEqual(accounts.ethereum, [])
            XCTAssertEqual(accounts.avalanche, [self.avalancheAccount])
            avalancheOnly.fulfill()
        }
        signer.accounts(type: .ethereumOnly) { res in
            let accounts = try! res.get()
            XCTAssertEqual(accounts.ethereum, [self.ethereumAccount])
            XCTAssertEqual(accounts.avalanche, [])
            ethereumOnly.fulfill()
        }
        signer.accounts(type: .both) { res in
            let accounts = try! res.get()
            XCTAssertEqual(accounts.ethereum, [self.ethereumAccount])
            XCTAssertEqual(accounts.avalanche, [self.avalancheAccount])
            both.fulfill()
        }
        wait(for: [avalancheOnly, ethereumOnly, both], timeout: 10)
    }
    
    func testSignTransaction() throws {
        let success = expectation(description: "success")
        let transaction = try ExtendedAvalancheTransaction(
            transaction: try BaseTransaction(
                networkID: .test,
                blockchainID: BlockchainID(data: Data(count: BlockchainID.size))!,
                outputs: [],
                inputs: [
                    TransferableInput(
                        transactionID: TransactionID(data: Data(count: TransactionID.size))!,
                        utxoIndex: 0,
                        assetID: AssetID(data: Data(count: AssetID.size))!,
                        input: SECP256K1TransferInput(
                            amount: 1,
                            addressIndices: [0]
                        )
                    )
                ],
                memo: Data(count: 1)
            ),
            utxos: [
                UTXO(
                    transactionID: TransactionID(data: Data(count: TransactionID.size))!,
                    utxoIndex: 0,
                    assetID: AssetID(data: Data(count: AssetID.size))!,
                    output: SECP256K1TransferOutput(
                        amount: 1,
                        locktime: Date(timeIntervalSince1970: 0),
                        threshold: 1,
                        addresses: [avalancheAddress.address]
                    )
                )
            ],
            pathes: [avalancheAddress.address: avalancheAddress.path]
        )
        let data = try transaction.serialized()
        let signatures = [
            avalancheKeyPair.signAvalanche(serialized: data)!
        ]
        let testSigned = SignedAvalancheTransaction(
            unsignedTransaction: transaction.transaction,
            credentials: [
                SECP256K1Credential(signatures: signatures)
            ]
        )
        signer.sign(transaction: transaction) { res in
            let signed = try! res.get()
            XCTAssertEqual(signed, testSigned)
            success.fulfill()
        }
        wait(for: [success], timeout: 10)
    }
    
    func testSignMessage() throws {
        let signAvalanche = expectation(description: "signAvalanche")
        let signEthereum = expectation(description: "signEthereum")
        let message = Data([1, 2, 3])
        let testAvalancheSignature = avalancheKeyPair.signAvalanche(message: message)
        signer.sign(message: message, address: avalancheAddress) { res in
            let avalancheSignature = try! res.get()
            XCTAssertEqual(avalancheSignature, testAvalancheSignature)
            signAvalanche.fulfill()
        }
        let testEthereumSignature = ethereumKeyPair.signEthereum(message: message)
        signer.sign(message: message, address: ethereumAccount) { res in
            let ethereumSignature = try! res.get()
            XCTAssertEqual(ethereumSignature, testEthereumSignature)
            signEthereum.fulfill()
        }
        wait(for: [signAvalanche, signEthereum], timeout: 10)
    }
}
