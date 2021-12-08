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
    private var testUtxos: [UTXO]!
    private var testTransactionID: TransactionID!
    
    private static func newAssetID() -> AssetID {
        AssetID(data: Data((0..<AssetID.size).map { _ in
            UInt8.random(in: (0...UInt8.max))
        }))!
    }
    
    private static func newTransactionID() -> TransactionID {
        TransactionID(data: Data((0..<TransactionID.size).map { _ in
            UInt8.random(in: (0...UInt8.max))
        }))!
    }
    
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
        let utxoTransactionID = Self.newTransactionID()
        testUtxos = [
            UTXO(
                transactionID: utxoTransactionID,
                utxoIndex: 1,
                assetID: self.avaxAssetID,
                output: try! SECP256K1TransferOutput(
                    amount: 100_000_000,
                    locktime: Date(timeIntervalSince1970: 0),
                    threshold: 1,
                    addresses: [testFromAddress.address]
                )
            ), UTXO(
                transactionID: utxoTransactionID,
                utxoIndex: 2,
                assetID: self.avaxAssetID,
                output: try! SECP256K1MintOutput(
                    locktime: Date(timeIntervalSince1970: 0),
                    threshold: 1,
                    addresses: [testFromAddress.address]
                )
            ), UTXO(
                transactionID: utxoTransactionID,
                utxoIndex: 3,
                assetID: self.avaxAssetID,
                output: try! NFTMintOutput(
                    groupID: 1,
                    locktime: Date(timeIntervalSince1970: 0),
                    threshold: 1,
                    addresses: [testFromAddress.address]
                )
            )
        ]
        testTransactionID = Self.newTransactionID()
    }
    
    private var api: AvalancheXChainApi {
        avalanche.xChain
    }
    
    private var utxoProvider: AvalancheUtxoProvider {
        let utxoProvider = UtxoProviderMock()
        utxoProvider.utxosAddressesMock = { api, addresses in
            var utxos = [UTXO]()
            if addresses == [self.testFromAddress.address] {
                utxos = self.testUtxos
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
    
    private func inputsOutputs(
        utxos: [UTXO],
        from: [Address],
        fee: UInt64
    ) throws -> ([TransferableInput], [TransferableOutput]) {
        let utxo = utxos.first { type(of: $0.output) == SECP256K1TransferOutput.self }!
        let output = utxo.output as! SECP256K1TransferOutput
        let inputs = [
            TransferableInput(
                transactionID: utxo.transactionID,
                utxoIndex: utxo.utxoIndex,
                assetID: utxo.assetID,
                input: try SECP256K1TransferInput(
                    amount: output.amount,
                    addressIndices: output.getAddressIndices(for: from)
                )
            )
        ]
        let change = output.amount - fee
        let outputs = [
            TransferableOutput(
                assetID: avaxAssetID,
                output: try type(of: output).init(
                    amount: change,
                    locktime: Date(timeIntervalSince1970: 0),
                    threshold: 1,
                    addresses: from
                )
            )
        ]
        return (inputs, outputs)
    }
    
    func testCreateFixedCapAsset() throws {
        let success = expectation(description: "success")
        let name = "name"
        let symbol = "symbol"
        let denomination: UInt8 = 1
        let initialHolders = [
            (address: newAddress().address, amount: UInt64(1))
        ]
        let fromAddress = testFromAddress.address
        let fromAddressPath = testFromAddress.path
        let testChangeAddress = newAddress().address
        let memo = "memo".data(using: .utf8)!
        let testAssetID = AssetID(data: self.testTransactionID.raw)!
        let signatureProvider = SignatureProviderMock()
        let fee = UInt64(api.info.creationTxFee)
        let (inputs, outputs) = try inputsOutputs(utxos: testUtxos, from: [fromAddress], fee: fee)
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
                    addresses: [fromAddress]
                )
            ]
        )]
        signatureProvider.signTransactionMock = { transaction, cb in
            let extended = transaction as! ExtendedAvalancheTransaction
            XCTAssertEqual(extended.pathes, [fromAddress: fromAddressPath])
            assert(extended.utxoAddresses.first!.0 == SECP256K1Credential.self)
            XCTAssertEqual(extended.utxoAddresses.first!.1, [fromAddress])
            let transaction = extended.transaction as! CreateAssetTransaction
            let testTransaction = try! CreateAssetTransaction(
                networkID: self.api.networkID,
                blockchainID: self.api.info.blockchainID,
                outputs: outputs,
                inputs: inputs,
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
            from: [fromAddress],
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
    
    func testMint() throws {
        let success = expectation(description: "success")
        let amount: UInt64 = 50_000_000
        let testChangeAddress = newAddress().address
        let toAddress = newAddress().address
        let memo = "memo".data(using: .utf8)!
        let fromAddress = testFromAddress.address
        let fromAddressPath = testFromAddress.path
        let assetID = Self.newAssetID()
        let signatureProvider = SignatureProviderMock()
        let fee = UInt64(api.info.txFee)
        let (inputs, outputs) = try inputsOutputs(utxos: testUtxos, from: [fromAddress], fee: fee)
        let mintUTXO = testUtxos.first { type(of: $0.output) == SECP256K1MintOutput.self }!
        let mintOutput = mintUTXO.output as! SECP256K1MintOutput
        let addressIndices = mintOutput.getAddressIndices(for: [fromAddress])
        let transferOutput = try! SECP256K1TransferOutput(
            amount: amount,
            locktime: Date(timeIntervalSince1970: 0),
            threshold: 1,
            addresses: [fromAddress]
        )
        let mintOperation = SECP256K1MintOperation(
            addressIndices: addressIndices,
            mintOutput: mintOutput,
            transferOutput: transferOutput
        )
        let transferableOperation = TransferableOperation(
            assetID: mintUTXO.assetID,
            utxoIDs: [
                UTXOID(
                    transactionID: mintUTXO.transactionID,
                    utxoIndex: mintUTXO.utxoIndex
                )
            ],
            transferOperation: mintOperation
        )
        signatureProvider.signTransactionMock = { transaction, cb in
            let extended = transaction as! ExtendedAvalancheTransaction
            XCTAssertEqual(extended.pathes, [fromAddress: fromAddressPath])
            assert(extended.utxoAddresses.first!.0 == SECP256K1Credential.self)
            XCTAssertEqual(extended.utxoAddresses.first!.1, [fromAddress])
            let transaction = extended.transaction as! OperationTransaction
            let testTransaction = try! OperationTransaction(
                networkID: self.api.networkID,
                blockchainID: self.api.info.blockchainID,
                outputs: outputs,
                inputs: inputs,
                memo: memo,
                operations: [transferableOperation]
            )
            XCTAssertEqual(transaction, testTransaction)
            cb(.success(SignedAvalancheTransaction(
                unsignedTransaction: transaction,
                credentials: []
            )))
        }
        avalanche.signatureProvider = signatureProvider
        api.mint(
            amount: amount,
            assetID: assetID,
            to: toAddress,
            from: [fromAddress],
            change: testChangeAddress,
            memo: memo,
            credentials: .account(testAccount)
        ) { res in
            let (transactionID, changeAddress) = try! res.get()
            XCTAssertEqual(transactionID, self.testTransactionID)
            XCTAssertEqual(changeAddress, testChangeAddress)
            success.fulfill()
        }
        wait(for: [success], timeout: 10)
    }
    
    func testCreateVariableCapAsset() throws {
        let success = expectation(description: "success")
        let name = "name"
        let symbol = "symbol"
        let denomination: UInt8 = 1
        let minterSets = [
            (minters: [newAddress().address], threshold: UInt32(1))
        ]
        let fromAddress = testFromAddress.address
        let fromAddressPath = testFromAddress.path
        let testChangeAddress = newAddress().address
        let memo = "memo".data(using: .utf8)!
        let testAssetID = AssetID(data: self.testTransactionID.raw)!
        let signatureProvider = SignatureProviderMock()
        let fee = UInt64(api.info.creationTxFee)
        let (inputs, outputs) = try inputsOutputs(utxos: testUtxos, from: [fromAddress], fee: fee)
        let testInitialStates = [InitialState(
            featureExtensionID: .secp256K1,
            outputs: minterSets.map { minters, threshold in
                try! SECP256K1MintOutput(
                    locktime: Date(timeIntervalSince1970: 0),
                    threshold: threshold,
                    addresses: minters
                )
            }
        )]
        signatureProvider.signTransactionMock = { transaction, cb in
            let extended = transaction as! ExtendedAvalancheTransaction
            XCTAssertEqual(extended.pathes, [fromAddress: fromAddressPath])
            assert(extended.utxoAddresses.first!.0 == SECP256K1Credential.self)
            XCTAssertEqual(extended.utxoAddresses.first!.1, [fromAddress])
            let transaction = extended.transaction as! CreateAssetTransaction
            let testTransaction = try! CreateAssetTransaction(
                networkID: self.api.networkID,
                blockchainID: self.api.info.blockchainID,
                outputs: outputs,
                inputs: inputs,
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
        api.createVariableCapAsset(
            name: name,
            symbol: symbol,
            denomination: denomination,
            minterSets: minterSets,
            from: [fromAddress],
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
    
    func testCreateNFTAsset() throws {
        let success = expectation(description: "success")
        let name = "name"
        let symbol = "symbol"
        let minterSets = [
            (minters: [newAddress().address], threshold: UInt32(1))
        ]
        let fromAddress = testFromAddress.address
        let fromAddressPath = testFromAddress.path
        let testChangeAddress = newAddress().address
        let memo = "memo".data(using: .utf8)!
        let testAssetID = AssetID(data: self.testTransactionID.raw)!
        let signatureProvider = SignatureProviderMock()
        let fee = UInt64(api.info.creationTxFee)
        let (inputs, outputs) = try inputsOutputs(utxos: testUtxos, from: [fromAddress], fee: fee)
        let testInitialStates = [InitialState(
            featureExtensionID: .nft,
            outputs: try minterSets.enumerated().map { index, minterSet in
                try NFTMintOutput(
                    groupID: UInt32(index),
                    locktime: Date(timeIntervalSince1970: 0),
                    threshold: minterSet.threshold,
                    addresses: minterSet.minters
                )
            }
        )]
        signatureProvider.signTransactionMock = { transaction, cb in
            let extended = transaction as! ExtendedAvalancheTransaction
            XCTAssertEqual(extended.pathes, [fromAddress: fromAddressPath])
            assert(extended.utxoAddresses.first!.0 == SECP256K1Credential.self)
            XCTAssertEqual(extended.utxoAddresses.first!.1, [fromAddress])
            let transaction = extended.transaction as! CreateAssetTransaction
            let testTransaction = try! CreateAssetTransaction(
                networkID: self.api.networkID,
                blockchainID: self.api.info.blockchainID,
                outputs: outputs,
                inputs: inputs,
                memo: memo,
                name: name,
                symbol: symbol,
                denomination: 0,
                initialStates: testInitialStates
            )
            XCTAssertEqual(transaction, testTransaction)
            cb(.success(SignedAvalancheTransaction(
                unsignedTransaction: transaction,
                credentials: []
            )))
        }
        avalanche.signatureProvider = signatureProvider
        api.createNFTAsset(
            name: name,
            symbol: symbol,
            minterSets: minterSets,
            from: [fromAddress],
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
    
    func testMintNFT() throws {
        let success = expectation(description: "success")
        let payload = "0x010203"
        let testChangeAddress = newAddress().address
        let toAddress = newAddress().address
        let memo = "memo".data(using: .utf8)!
        let fromAddress = testFromAddress.address
        let fromAddressPath = testFromAddress.path
        let assetID = Self.newAssetID()
        let signatureProvider = SignatureProviderMock()
        let fee = UInt64(api.info.txFee)
        let (inputs, outputs) = try inputsOutputs(utxos: testUtxos, from: [fromAddress], fee: fee)
        let mintUTXO = testUtxos.first { type(of: $0.output) == NFTMintOutput.self }!
        let mintOutput = mintUTXO.output as! NFTMintOutput
        let addressIndices = mintOutput.getAddressIndices(for: [fromAddress])
        let outputOwners = try NFTMintOperationOutput(
            locktime: Date(timeIntervalSince1970: 0),
            threshold: 1,
            addresses: [fromAddress]
        )
        let nftMintOperation = try NFTMintOperation(
            addressIndices: addressIndices,
            groupID: 0,
            payload: Data(hex: payload)!,
            outputs: [outputOwners]
        )
        let transferableOperation = TransferableOperation(
            assetID: mintUTXO.assetID,
            utxoIDs: [
                UTXOID(
                    transactionID: mintUTXO.transactionID,
                    utxoIndex: mintUTXO.utxoIndex
                )
            ],
            transferOperation: nftMintOperation
        )
        signatureProvider.signTransactionMock = { transaction, cb in
            let extended = transaction as! ExtendedAvalancheTransaction
            XCTAssertEqual(extended.pathes, [fromAddress: fromAddressPath])
            assert(extended.utxoAddresses.first!.0 == SECP256K1Credential.self)
            XCTAssertEqual(extended.utxoAddresses.first!.1, [fromAddress])
            let transaction2 = extended.transaction as! OperationTransaction
            let testTransaction = try! OperationTransaction(
                networkID: self.api.networkID,
                blockchainID: self.api.info.blockchainID,
                outputs: outputs,
                inputs: inputs,
                memo: memo,
                operations: [transferableOperation]
            )
            XCTAssertEqual(transaction2, testTransaction)
            cb(.success(SignedAvalancheTransaction(
                unsignedTransaction: transaction2,
                credentials: []
            )))
        }
        avalanche.signatureProvider = signatureProvider
        api.mintNFT(
            assetID: assetID,
            payload: payload,
            to: toAddress,
            from: [fromAddress],
            change: testChangeAddress,
            memo: memo,
            credentials: .account(testAccount)
        ) { res in
            let (transactionID, changeAddress) = try! res.get()
            XCTAssertEqual(transactionID, self.testTransactionID)
            XCTAssertEqual(changeAddress, testChangeAddress)
            success.fulfill()
        }
        wait(for: [success], timeout: 10)
    }
}
