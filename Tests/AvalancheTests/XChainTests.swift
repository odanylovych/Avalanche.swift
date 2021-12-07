//
//  XChainTests.swift
//  
//
//  Created by Ostap Danylovych on 03.12.2021.
//

import Foundation
import XCTest
@testable import Avalanche
import RPC

final class XChainTests: XCTestCase {
    private let avaxAssetID = AssetID(data: Data(count: AssetID.size))!
    
    private var avalanche: AvalancheCore!
    private var testAccount: Account!
    private var addressIndex: UInt32!
    private var testFromAddress: ExtendedAddress!
    private var testUtxo: UTXO!
    private var testTransactionID: TransactionID!
    
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
                throw ApiTestsError.error(from: "getAPIMock")
            }
        }
        avalanche.utxoProvider = utxoProvider
        avalanche.addressManager = addressManager
        avalanche.connectionProvider = connectionProvider
        self.avalanche = avalanche
        testAccount = try! Account(
            pubKey: Data(hex: "0x02ccbf163222a621523a477389b2b6318b9c43b424bdf4b74340e9b45443cc0506")!,
            chainCode: Data(count: 32),
            path: try! Bip32Path.prefixAvalanche.appending(0, hard: true)
        )
        addressIndex = 0
        testFromAddress = newAddress()
        testUtxo = UTXO(
            transactionID: TransactionID(data: Data(count: TransactionID.size))!,
            utxoIndex: 1,
            assetID: self.avaxAssetID,
            output: try! SECP256K1TransferOutput(
                amount: 100_000_000,
                locktime: Date(timeIntervalSince1970: 0),
                threshold: 1,
                addresses: [testFromAddress.address]
            )
        )
        testTransactionID = TransactionID(data: Data((0..<TransactionID.size).map { UInt8($0) }))!
    }
    
    private var api: AvalancheXChainApi {
        avalanche.xChain
    }
    
    private var utxoProvider: AvalancheUtxoProvider {
        let utxoProvider = UtxoProviderMock()
        utxoProvider.utxosAddressesMock = { api, addresses in
            var utxos = [UTXO]()
            if addresses == [self.testFromAddress.address] {
                utxos = [self.testUtxo]
            } else {
                XCTFail("utxosAddressesMock")
            }
            return UtxoProviderMock.IteratorMock(nextMock: { limit, sourceChain, result in
                result(.success((utxos, nil)))
            })
        }
        return utxoProvider
    }
    
    private var addressManager: AvalancheAddressManager {
        let addressManager = AddressManagerMock()
        addressManager.extendedAvmMock = { addresses in
            guard addresses == [self.testFromAddress.address] else {
                throw ApiTestsError.error(from: "extendedAvmMock")
            }
            return [self.testFromAddress]
        }
        return addressManager
    }
    
    private var connectionProvider: AvalancheConnectionProvider {
        var connectionProvider = ConnectionProviderMock()
        connectionProvider.rpcMock = { api in
            guard case .xChain = api else {
                return ClientMock(callMock: { $2(.failure(ApiTestsError.error(from: "rpcMock"))) })
            }
            return ClientMock(callMock: { method, params, response in
                switch method {
                case "avm.getAssetDescription":
                    let params = params as! AvalancheXChainApi.GetAssetDescriptionParams
                    XCTAssertEqual(params.assetID, AvalancheConstants.avaxAssetAlias)
                    response(.success(AvalancheXChainApi.GetAssetDescriptionResponse(
                        assetID: self.avaxAssetID.cb58(),
                        name: "asset name",
                        symbol: "asset symbol",
                        denomination: 0
                    )))
                case "avm.issueTx":
                    response(.success(AvalancheXChainApi.IssueTxResponse(
                        txID: self.testTransactionID.cb58()
                    )))
                default:
                    response(.failure(ApiTestsError.error(description: "no mock for api method \(method)")))
                }
            })
        }
        return connectionProvider
    }
    
    private func newAddress() -> ExtendedAddress {
        let extended = try! testAccount.derive(
            index: addressIndex,
            change: false,
            hrp: api.hrp,
            chainId: api.info.chainId
        )
        addressIndex += 1
        return extended
    }
    
    func testCreateFixedCapAsset() throws {
        let success = expectation(description: "success")
        let name = "name"
        let symbol = "symbol"
        let denomination: UInt8 = 1
        let initialHolders = [
            (address: newAddress().address, amount: UInt64(1))
        ]
        let from = testFromAddress.address
        let path = testFromAddress.path
        let testChangeAddress = newAddress().address
        let memo = "memo".data(using: .utf8)!
        let testAssetID = AssetID(data: self.testTransactionID.raw)!
        let signatureProvider = SignatureProviderMock()
        let output = testUtxo.output as! SECP256K1TransferOutput
        let testInputs = [TransferableInput(
            transactionID: testUtxo.transactionID,
            utxoIndex: testUtxo.utxoIndex,
            assetID: testUtxo.assetID,
            input: try! SECP256K1TransferInput(
                amount: output.amount,
                addressIndices: output.getAddressIndices(for: [from])
            )
        )]
        let change = output.amount - UInt64(api.info.creationTxFee)
        let testOutputs = [TransferableOutput(
            assetID: avaxAssetID,
            output: try! type(of: output).init(
                amount: change,
                locktime: Date(timeIntervalSince1970: 0),
                threshold: 1,
                addresses: [from]
            )
        )]
        let testInitialStates = [InitialState(
            featureExtensionID: .secp256K1,
            outputs: try! initialHolders.map { address, amount in
                try! SECP256K1TransferOutput(
                    amount: amount,
                    locktime: Date(timeIntervalSince1970: 0),
                    threshold: 1,
                    addresses: [address]
                )
            } + [
                SECP256K1MintOutput(
                    locktime: Date(timeIntervalSince1970: 0),
                    threshold: 1,
                    addresses: [from]
                )
            ]
        )]
        signatureProvider.signTransactionMock = { transaction, cb in
            let extended = transaction as! ExtendedAvalancheTransaction
            XCTAssertEqual(extended.pathes, [from: path])
            assert(extended.utxoAddresses.first!.0 == SECP256K1Credential.self)
            XCTAssertEqual(extended.utxoAddresses.first!.1, [from])
            let transaction = extended.transaction as! CreateAssetTransaction
            let testTransaction = try! CreateAssetTransaction(
                networkID: self.api.networkID,
                blockchainID: self.api.info.blockchainID,
                outputs: testOutputs,
                inputs: testInputs,
                memo: memo,
                name: name,
                symbol: symbol,
                denomination: denomination,
                initialStates: testInitialStates
            )
            XCTAssertEqual(transaction, testTransaction)
            cb(.success(SignedAvalancheTransaction(
                unsignedTransaction: transaction,
                credentials: []
            )))
        }
        avalanche.signatureProvider = signatureProvider
        api.createFixedCapAsset(
            name: name,
            symbol: symbol,
            denomination: denomination,
            initialHolders: initialHolders,
            from: [from],
            change: testChangeAddress,
            memo: memo,
            credentials: .account(testAccount)
        ) { res in
            let (assetID, changeAddress) = try! res.get()
            XCTAssertEqual(assetID, testAssetID)
            XCTAssertEqual(changeAddress, testChangeAddress)
            success.fulfill()
        }
        wait(for: [success], timeout: 10)
    }
}
