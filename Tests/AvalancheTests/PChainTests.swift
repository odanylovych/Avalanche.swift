//
//  PChainTests.swift
//  
//
//  Created by Ostap Danylovych on 14.12.2021.
//

import Foundation
import XCTest
@testable import Avalanche
import RPC

final class PChainTests: XCTestCase {
    private var avalanche: AvalancheCore!
    private var testAccount: Account!
    private var idIndex: UInt8!
    private var avaxAssetID: AssetID!
    private var addressIndex: UInt32!
    private var testFromAddress: ExtendedAddress!
    private var testChangeAddress: Address!
    private var utxoForInput: UTXO!
    private var testUtxos: [UTXO]!
    private var testTransactionID: TransactionID!
    
    override func setUp() {
        super.setUp()
        let avalanche = AvalancheCoreMock()
        avalanche.getAPIMock = avalanche.defaultGetAPIMock(for: .test)
        avalanche.utxoProvider = utxoProvider
        avalanche.addressManager = addressManager
        avalanche.connectionProvider = connectionProvider
        self.avalanche = avalanche
        testAccount = try! Account(
            pubKey: Data(hex: "0x02ccbf163222a621523a477389b2b6318b9c43b424bdf4b74340e9b45443cc0506")!,
            chainCode: Data(count: 32),
            path: try! Bip32Path.prefixAvalanche.appending(0, hard: true)
        )
        idIndex = 0
        addressIndex = 0
        avaxAssetID = newAssetID()
        testFromAddress = newAddress()
        testChangeAddress = newAddress().address
        testTransactionID = newTransactionID()
        let utxoTransactionID = newTransactionID()
        utxoForInput = UTXO(
            transactionID: utxoTransactionID,
            utxoIndex: 0,
            assetID: avaxAssetID,
            output: try! SECP256K1TransferOutput(
                amount: 100_000_000,
                locktime: Date(timeIntervalSince1970: 0),
                threshold: 1,
                addresses: [testFromAddress.address]
            )
        )
        testUtxos = [
            utxoForInput
        ]
    }
    
    private var api: AvalanchePChainApi {
        avalanche.pChain
    }
    
    private var utxoProvider: AvalancheUtxoProvider {
        let utxoProvider = UtxoProviderMock()
        utxoProvider.utxosAddressesMock = { api, addresses in
            precondition(addresses == [self.testFromAddress.address])
            return UtxoProviderMock.IteratorMock(nextMock: { limit, sourceChain, result in
                result(.success((self.testUtxos, nil)))
            })
        }
        return utxoProvider
    }
    
    private var addressManager: AvalancheAddressManager {
        let addressManager = AddressManagerMock()
        addressManager.newMock = { api, account, change, count in
            precondition(account == self.testAccount)
            precondition(change == true)
            precondition(count == 1)
            return [self.testChangeAddress]
        }
        addressManager.getCachedMock = { api, account in
            [self.testFromAddress.address]
        }
        addressManager.extendedAvmMock = { addresses in
            precondition(addresses == [self.testFromAddress.address])
            return [self.testFromAddress]
        }
        return addressManager
    }
    
    private var connectionProvider: AvalancheConnectionProvider {
        var connectionProvider = ConnectionProviderMock()
        connectionProvider.rpcMock = { api in
            guard case .pChain = api else {
                return ClientMock(callMock: { $2(.failure(ApiTestsError.error(from: "rpcMock"))) })
            }
            return ClientMock(callMock: { method, params, response in
                switch method {
                case "platform.getStakingAssetID":
                    response(.success(AvalanchePChainApi.GetStakingAssetIDResponse(assetID: self.avaxAssetID.cb58())))
                case "platform.issueTx":
                    response(.success(AvalanchePChainApi.IssueTxResponse(
                        txID: self.testTransactionID.cb58()
                    )))
                default:
                    response(.failure(ApiTestsError.error(description: "no mock for api method \(method)")))
                }
            })
        }
        return connectionProvider
    }
    
    private func newAssetID() -> AssetID {
        let assetID = AssetID(data: Data(repeating: idIndex, count: AssetID.size))!
        idIndex += 1
        return assetID
    }
    
    private func newTransactionID() -> TransactionID {
        let transactionID = TransactionID(data: Data(repeating: idIndex, count: TransactionID.size))!
        idIndex += 1
        return transactionID
    }
    
    private func newAddress<API: AvalancheVMApi>(api: API) -> ExtendedAddress {
        let extended = try! testAccount.derive(
            index: addressIndex,
            change: false,
            hrp: api.hrp,
            chainId: api.info.chainId
        )
        addressIndex += 1
        return extended
    }
    
    private func newAddress() -> ExtendedAddress {
        newAddress(api: api)
    }
}
