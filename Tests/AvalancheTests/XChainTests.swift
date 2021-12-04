//
//  XChainTests.swift
//  
//
//  Created by Ostap Danylovych on 03.12.2021.
//

import Foundation
import XCTest
import Avalanche

final class XChainTests: XCTestCase {
    private var xChain: AvalancheXChainApi!
    private var testAccount: Account!
    private var addressIndex: UInt32!
    
    private var testFromAddress: ExtendedAddress!
    private var testUtxos: [UTXO]!
    
    override func setUp() {
        super.setUp()
        let avalanche = AvalancheCoreMock()
        avalanche.getAPIMock = { apiType in
            let networkID: NetworkID = .test
            let networkInfo = AvalancheDefaultNetworkInfoProvider.default.info(for: networkID)!
            if apiType == AvalancheXChainApi.self {
                return AvalancheXChainApi(
                    avalanche: avalanche,
                    networkID: networkID,
                    hrp: networkInfo.hrp,
                    info: networkInfo.apiInfo.info(for: AvalancheXChainApi.self)!
                )
            } else if apiType == AvalanchePChainApi.self {
                return AvalanchePChainApi(
                    avalanche: avalanche,
                    networkID: networkID,
                    hrp: networkInfo.hrp,
                    info: networkInfo.apiInfo.info(for: AvalanchePChainApi.self)!
                )
            } else if apiType == AvalancheCChainApi.self {
                return AvalancheCChainApi(
                    avalanche: avalanche,
                    networkID: networkID,
                    hrp: networkInfo.hrp,
                    info: networkInfo.apiInfo.info(for: AvalancheCChainApi.self)!
                )
            } else {
                throw ApiTestsError.error(from: "getAPI")
            }
        }
        avalanche.urlMock = { path in
            URL(string: "http://test")!
        }
        avalanche.utxoProvider = utxoProvider
        avalanche.addressManager = AddressManagerMock()
        xChain = avalanche.xChain
        testAccount = try! Account(
            pubKey: Data(hex: "0x02ccbf163222a621523a477389b2b6318b9c43b424bdf4b74340e9b45443cc0506")!,
            chainCode: Data(count: 32),
            path: try! Bip32Path.prefixAvalanche.appending(0, hard: true)
        )
        addressIndex = 0
        testFromAddress = newAddress()
        testUtxos = [UTXO(
            transactionID: TransactionID(data: Data(count: TransactionID.size))!,
            utxoIndex: 1,
            assetID: AssetID(data: Data(count: AssetID.size))!,
            output: try! SECP256K1TransferOutput(
                amount: 1,
                locktime: Date(timeIntervalSince1970: 0),
                threshold: 0,
                addresses: [newAddress().address]
            )
        )]
    }
    
    private var utxoProvider: AvalancheUtxoProvider {
        let utxoProvider = UtxoProviderMock()
        utxoProvider.utxosAddressesMock = { api, addresses in
            var utxos = [UTXO]()
            if addresses == [self.testFromAddress.address] {
                utxos = self.testUtxos
            } else {
                XCTFail("utxos addresses")
            }
            return UtxoProviderMock.IteratorMock(nextMock: { limit, sourceChain, result in
                result(.success((utxos, nil)))
            })
        }
        return utxoProvider
    }
    
    private func newAddress() -> ExtendedAddress {
        let extended = try! testAccount.derive(
            index: addressIndex,
            change: false,
            hrp: xChain.hrp,
            chainId: xChain.info.chainId
        )
        addressIndex += 1
        return extended
    }
    
    func testCreateFixedCapAsset() throws {
        // TODO: provide all mocks
        let success = expectation(description: "success")
        let name = "name"
        let symbol = "symbol"
        let denomination: UInt8 = 1
        let initialHolders = [
            (address: newAddress().address, amount: UInt64(1))
        ]
        let from = newAddress().address
        let testChange = newAddress().address
        let memo = Data()
        let testAssetID = AssetID(data: Data(count: AssetID.size))!
        xChain.createFixedCapAsset(
            name: name,
            symbol: symbol,
            denomination: denomination,
            initialHolders: initialHolders,
            from: [from],
            change: testChange,
            memo: memo,
            credentials: .account(testAccount)
        ) { res in
            let (assetID, change) = try! res.get()
            XCTAssertEqual(assetID, testAssetID)
            XCTAssertEqual(change, testChange)
            success.fulfill()
        }
        wait(for: [success], timeout: 10)
    }
}
