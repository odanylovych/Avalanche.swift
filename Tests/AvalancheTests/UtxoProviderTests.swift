//
//  UtxoProviderTests.swift
//  
//
//  Created by Ostap Danylovych on 27.11.2021.
//

import Foundation
import XCTest
@testable import Avalanche

final class UtxoProviderTests: XCTestCase {
    private var avalanche: AvalancheCore!
    private var api: AvalancheVMApiMock!
    
    override func setUp() {
        super.setUp()
        avalanche = AvalancheCoreMock()
        api = AvalancheVMApiMock(avalanche: avalanche)
    }
    
    func testUtxosIds() throws {
        let success = expectation(description: "success")
        let testTransactionId = TransactionID(data: Data(count: TransactionID.size))!
        let testUtxoIndex: UInt32 = 0
        let testAssetID = AssetID(data: Data(count: AssetID.size))!
        let testOutput = try SECP256K1TransferOutput(
            amount: 1,
            locktime: Date(timeIntervalSince1970: 0),
            threshold: 0,
            addresses: []
        )
        let testIds = [
            (txID: testTransactionId, index: testUtxoIndex)
        ]
        let testUtxo = UTXO(
            transactionID: testTransactionId,
            utxoIndex: testUtxoIndex,
            assetID: testAssetID,
            output: testOutput
        )
        api.getTransactionMock = { id, result in
            guard id == testTransactionId else {
                XCTFail("getTransaction")
                return
            }
            result(.success(SignedAvalancheTransaction(
                unsignedTransaction: try! BaseTransaction(
                    networkID: NetworkID.local,
                    blockchainID: BlockchainID(data: Data(count: BlockchainID.size))!,
                    outputs: [
                        TransferableOutput(
                            assetID: testAssetID,
                            output: testOutput
                        )
                    ],
                    inputs: [],
                    memo: Data()
                ),
                credentials: []
            )))
        }
        let utxoProvider = AvalancheDefaultUtxoProvider()
        utxoProvider.utxos(api: api, ids: testIds) { res in
            let utxos = try! res.get()
            XCTAssertEqual(utxos, [testUtxo])
            success.fulfill()
        }
        wait(for: [success], timeout: 10)
    }
    
    func testUtxosAddresses() throws {
        let success = expectation(description: "success")
        let account = try Account(
            pubKey: Data(hex: "0x02ccbf163222a621523a477389b2b6318b9c43b424bdf4b74340e9b45443cc0506")!,
            chainCode: Data(count: 32),
            path: try Bip32Path.prefixAvalanche.appending(0, hard: true)
        )
        let testAddresses = try (0..<2).map { index in
            try account.derive(
                index: index,
                change: false,
                hrp: api.hrp,
                chainId: api.info.chainId
            ).address
        }
        let testUtxos = try (0..<2).map { index in
            UTXO(
                transactionID: TransactionID(data: Data(count: TransactionID.size))!,
                utxoIndex: UInt32(index),
                assetID: AssetID(data: Data(count: AssetID.size))!,
                output: try SECP256K1TransferOutput(
                    amount: UInt64(index + 1),
                    locktime: Date(timeIntervalSince1970: 0),
                    threshold: 0,
                    addresses: [testAddresses[index]]
                )
            )
        }
        let endIndex1 = UTXOIndex(
            address: testAddresses[0].bech,
            utxo: try! AEncoder().encode(testUtxos[0]).output.hex()
        )
        let endIndex2 = UTXOIndex(
            address: testAddresses[1].bech,
            utxo: try! AEncoder().encode(testUtxos[1]).output.hex()
        )
        api.getUTXOsMock = { addresses, limit, startIndex, sourceChain, encoding, cb in
            guard addresses == testAddresses,
                  sourceChain == self.api.info.blockchainID,
                  encoding == AvalancheEncoding.cb58 else {
                XCTFail("getUTXOs")
                return
            }
            if startIndex == nil {
                cb(.success((
                    fetched: 1,
                    utxos: [testUtxos[0]],
                    endIndex: endIndex1,
                    encoding: AvalancheEncoding.cb58
                )))
            } else if startIndex == endIndex1 {
                cb(.success((
                    fetched: 1,
                    utxos: [testUtxos[1]],
                    endIndex: endIndex2,
                    encoding: AvalancheEncoding.cb58
                )))
            } else if startIndex == endIndex2 {
                cb(.success((
                    fetched: 0,
                    utxos: [],
                    endIndex: endIndex2,
                    encoding: AvalancheEncoding.cb58
                )))
            } else {
                XCTFail("Wrong startIndex")
            }
        }
        let utxoProvider = AvalancheDefaultUtxoProvider()
        let iterator = utxoProvider.utxos(api: api, addresses: testAddresses)
        UTXOHelper.getAll(iterator: iterator, limit: 1) { res in
            let utxos = try! res.get()
            XCTAssertEqual(utxos, testUtxos)
            success.fulfill()
        }
        wait(for: [success], timeout: 10)
    }
}
