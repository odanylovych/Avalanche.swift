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
            utxoForInput,
            UTXO(
                transactionID: utxoTransactionID,
                utxoIndex: 1,
                assetID: avaxAssetID,
                output: try! SECP256K1MintOutput(
                    locktime: Date(timeIntervalSince1970: 0),
                    threshold: 1,
                    addresses: [testFromAddress.address]
                )
            ), UTXO(
                transactionID: utxoTransactionID,
                utxoIndex: 2,
                assetID: avaxAssetID,
                output: try! NFTMintOutput(
                    groupID: 1,
                    locktime: Date(timeIntervalSince1970: 0),
                    threshold: 1,
                    addresses: [testFromAddress.address]
                )
            )
        ]
    }
    
    private var api: AvalancheXChainApi {
        avalanche.xChain
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
    
    private func inputsOutputs(
        fromAddresses: [Address],
        changeAddresses: [Address],
        fee: UInt64
    ) throws -> ([TransferableInput], [TransferableOutput]) {
        let output = utxoForInput.output as! SECP256K1TransferOutput
        let inputs = [
            TransferableInput(
                transactionID: utxoForInput.transactionID,
                utxoIndex: utxoForInput.utxoIndex,
                assetID: utxoForInput.assetID,
                input: try SECP256K1TransferInput(
                    amount: output.amount,
                    addressIndices: output.getAddressIndices(for: fromAddresses)
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
                    addresses: changeAddresses
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
        let (inputs, outputs) = try inputsOutputs(
            fromAddresses: [fromAddress],
            changeAddresses: [testChangeAddress],
            fee: fee
        )
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
            XCTAssert(extended.utxoAddresses.first!.0 == SECP256K1Credential.self)
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
        let assetID = newAssetID()
        let signatureProvider = SignatureProviderMock()
        let fee = UInt64(api.info.txFee)
        let (inputs, outputs) = try inputsOutputs(
            fromAddresses: [fromAddress],
            changeAddresses: [testChangeAddress],
            fee: fee
        )
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
            XCTAssert(extended.utxoAddresses.first!.0 == SECP256K1Credential.self)
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
        let (inputs, outputs) = try inputsOutputs(
            fromAddresses: [fromAddress],
            changeAddresses: [testChangeAddress],
            fee: fee
        )
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
            XCTAssert(extended.utxoAddresses.first!.0 == SECP256K1Credential.self)
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
        let (inputs, outputs) = try inputsOutputs(
            fromAddresses: [fromAddress],
            changeAddresses: [testChangeAddress],
            fee: fee
        )
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
            XCTAssert(extended.utxoAddresses.first!.0 == SECP256K1Credential.self)
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
        let assetID = newAssetID()
        let signatureProvider = SignatureProviderMock()
        let fee = UInt64(api.info.txFee)
        let (inputs, outputs) = try inputsOutputs(
            fromAddresses: [fromAddress],
            changeAddresses: [testChangeAddress],
            fee: fee
        )
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
            XCTAssert(extended.utxoAddresses.first!.0 == SECP256K1Credential.self)
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
    
    func testExport() throws {
        let success = expectation(description: "success")
        let amount: UInt64 = 50_000_000
        let testChangeAddress = newAddress().address
        let toChain = avalanche.pChain
        let toAddress = newAddress(api: toChain).address
        let memo = "memo".data(using: .utf8)!
        let fromAddress = testFromAddress.address
        let fromAddressPath = testFromAddress.path
        let assetID = newAssetID()
        let signatureProvider = SignatureProviderMock()
        let fee = UInt64(api.info.txFee)
        var (inputs, outputs) = try inputsOutputs(
            fromAddresses: [fromAddress],
            changeAddresses: [testChangeAddress],
            fee: fee
        )
        let utxo = UTXO(
            transactionID: newTransactionID(),
            utxoIndex: 0,
            assetID: assetID,
            output: try! SECP256K1TransferOutput(
                amount: 100_000_000,
                locktime: Date(timeIntervalSince1970: 0),
                threshold: 1,
                addresses: [testFromAddress.address]
            )
        )
        testUtxos = testUtxos + [utxo]
        inputs.append(TransferableInput(
            transactionID: utxo.transactionID,
            utxoIndex: utxo.utxoIndex,
            assetID: utxo.assetID,
            input: try SECP256K1TransferInput(
                amount: (utxo.output as! SECP256K1TransferOutput).amount,
                addressIndices: utxo.output.getAddressIndices(for: [fromAddress])
            )
        ))
        outputs.append(TransferableOutput(
            assetID: utxo.assetID,
            output: try SECP256K1TransferOutput(
                amount: (utxo.output as! SECP256K1TransferOutput).amount - amount,
                locktime: Date(timeIntervalSince1970: 0),
                threshold: 1,
                addresses: [testChangeAddress]
            )
        ))
        let exportOutputs = [
            TransferableOutput(
                assetID: assetID,
                output: try SECP256K1TransferOutput(
                    amount: amount,
                    locktime: Date(timeIntervalSince1970: 0),
                    threshold: 1,
                    addresses: [toAddress]
                )
            )
        ]
        let destinationChain = toChain.info.blockchainID
        signatureProvider.signTransactionMock = { tx, cb in
            let extended = tx as! ExtendedAvalancheTransaction
            XCTAssertEqual(extended.pathes, [fromAddress: fromAddressPath])
            XCTAssert(extended.utxoAddresses.first!.0 == SECP256K1Credential.self)
            XCTAssertEqual(extended.utxoAddresses.first!.1, [fromAddress])
            let transaction = extended.transaction as! ExportTransaction
            let testTransaction = try! ExportTransaction(
                networkID: self.api.networkID,
                blockchainID: self.api.info.blockchainID,
                outputs: outputs,
                inputs: inputs,
                memo: memo,
                destinationChain: destinationChain,
                transferableOutputs: exportOutputs
            )
            XCTAssertEqual(transaction.networkID, testTransaction.networkID)
            XCTAssertEqual(transaction.blockchainID, testTransaction.blockchainID)
            XCTAssertEqual(transaction.outputs.count, testTransaction.outputs.count)
            XCTAssert(transaction.outputs.allSatisfy(testTransaction.outputs.contains))
            XCTAssertEqual(transaction.inputs.count, testTransaction.inputs.count)
            XCTAssert(transaction.inputs.allSatisfy(testTransaction.inputs.contains))
            XCTAssertEqual(transaction.memo, testTransaction.memo)
            XCTAssertEqual(transaction.destinationChain, testTransaction.destinationChain)
            XCTAssertEqual(transaction.transferableOutputs, testTransaction.transferableOutputs)
            cb(.success(SignedAvalancheTransaction(
                unsignedTransaction: transaction,
                credentials: []
            )))
        }
        avalanche.signatureProvider = signatureProvider
        api.export(
            to: toAddress,
            amount: amount,
            assetID: assetID,
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
    
    func testImport() throws {
        let success = expectation(description: "success")
        let testSourceChain = BlockchainID(data: Data(repeating: 1, count: BlockchainID.size))!
        let toChain = avalanche.pChain
        let toAddress = newAddress(api: toChain).address
        let memo = "memo".data(using: .utf8)!
        let fromAddress = testFromAddress.address
        let fromAddressPath = testFromAddress.path
        let signatureProvider = SignatureProviderMock()
        let fee = UInt64(api.info.txFee)
        let inputs = [TransferableInput]()
        let utxo = utxoForInput!
        let output = utxo.output as! SECP256K1TransferOutput
        let inFeeAmount = output.amount - fee
        let outputs = [
            TransferableOutput(
                assetID: utxo.assetID,
                output: try SECP256K1TransferOutput.init(
                    amount: inFeeAmount,
                    locktime: Date(timeIntervalSince1970: 0),
                    threshold: 1,
                    addresses: [toAddress]
                )
            )
        ]
        let importInputs = [
            TransferableInput(
                transactionID: utxo.transactionID,
                utxoIndex: utxo.utxoIndex,
                assetID: utxo.assetID,
                input: try SECP256K1TransferInput(
                    amount: output.amount,
                    addressIndices: output.getAddressIndices(for: output.addresses)
                )
            )
        ]
        let utxoProvider = UtxoProviderMock()
        utxoProvider.utxosAddressesMock = { api, addresses in
            precondition(addresses == [self.testFromAddress.address])
            return UtxoProviderMock.IteratorMock(nextMock: { limit, sourceChain, result in
                precondition(sourceChain == testSourceChain)
                result(.success((self.testUtxos, nil)))
            })
        }
        avalanche.utxoProvider = utxoProvider
        signatureProvider.signTransactionMock = { tx, cb in
            let extended = tx as! ExtendedAvalancheTransaction
            XCTAssertEqual(extended.pathes, [fromAddress: fromAddressPath])
            XCTAssert(extended.utxoAddresses.first!.0 == SECP256K1Credential.self)
            XCTAssertEqual(extended.utxoAddresses.first!.1, [fromAddress])
            let transaction = extended.transaction as! ImportTransaction
            let testTransaction = try! ImportTransaction(
                networkID: self.api.networkID,
                blockchainID: self.api.info.blockchainID,
                outputs: outputs,
                inputs: inputs,
                memo: memo,
                sourceChain: testSourceChain,
                transferableInputs: importInputs
            )
            XCTAssertEqual(transaction, testTransaction)
            cb(.success(SignedAvalancheTransaction(
                unsignedTransaction: transaction,
                credentials: []
            )))
        }
        avalanche.signatureProvider = signatureProvider
        api.import(
            to: toAddress,
            sourceChain: testSourceChain,
            memo: memo,
            credentials: .account(testAccount)
        ) { res in
            let transactionID = try! res.get()
            XCTAssertEqual(transactionID, self.testTransactionID)
            success.fulfill()
        }
        wait(for: [success], timeout: 10)
    }
    
    func testSend() throws {
        let success = expectation(description: "success")
        let amount: UInt64 = 50_000_000
        let testChangeAddress = newAddress().address
        let toAddress = newAddress().address
        let memo = "memo"
        let fromAddress = testFromAddress.address
        let fromAddressPath = testFromAddress.path
        let assetID = newAssetID()
        let signatureProvider = SignatureProviderMock()
        let fee = UInt64(api.info.txFee)
        var (inputs, outputs) = try inputsOutputs(
            fromAddresses: [fromAddress],
            changeAddresses: [testChangeAddress],
            fee: fee
        )
        let utxo = UTXO(
            transactionID: newTransactionID(),
            utxoIndex: 0,
            assetID: assetID,
            output: try! SECP256K1TransferOutput(
                amount: 100_000_000,
                locktime: Date(timeIntervalSince1970: 0),
                threshold: 1,
                addresses: [testFromAddress.address]
            )
        )
        testUtxos = testUtxos + [utxo]
        inputs.append(TransferableInput(
            transactionID: utxo.transactionID,
            utxoIndex: utxo.utxoIndex,
            assetID: utxo.assetID,
            input: try SECP256K1TransferInput(
                amount: (utxo.output as! SECP256K1TransferOutput).amount,
                addressIndices: utxo.output.getAddressIndices(for: [fromAddress])
            )
        ))
        outputs.append(contentsOf: [
            TransferableOutput(
                assetID: utxo.assetID,
                output: try SECP256K1TransferOutput.init(
                    amount: (utxo.output as! SECP256K1TransferOutput).amount - amount,
                    locktime: Date(timeIntervalSince1970: 0),
                    threshold: 1,
                    addresses: [testChangeAddress]
                )
            ), TransferableOutput(
                assetID: utxo.assetID,
                output: try SECP256K1TransferOutput(
                    amount: (utxoForInput.output as! SECP256K1TransferOutput).amount - amount,
                    locktime: Date(timeIntervalSince1970: 0),
                    threshold: 1,
                    addresses: [toAddress]
                )
            )
        ])
        signatureProvider.signTransactionMock = { tx, cb in
            let extended = tx as! ExtendedAvalancheTransaction
            XCTAssertEqual(extended.pathes, [fromAddress: fromAddressPath])
            XCTAssert(extended.utxoAddresses.first!.0 == SECP256K1Credential.self)
            XCTAssertEqual(extended.utxoAddresses.first!.1, [fromAddress])
            let transaction = extended.transaction as! BaseTransaction
            let testTransaction = try! BaseTransaction(
                networkID: self.api.networkID,
                blockchainID: self.api.info.blockchainID,
                outputs: outputs,
                inputs: inputs,
                memo: memo.data(using: .utf8)!
            )
            XCTAssertEqual(transaction.networkID, testTransaction.networkID)
            XCTAssertEqual(transaction.blockchainID, testTransaction.blockchainID)
            XCTAssertEqual(transaction.outputs.count, testTransaction.outputs.count)
            XCTAssert(transaction.outputs.allSatisfy(testTransaction.outputs.contains))
            XCTAssertEqual(transaction.inputs.count, testTransaction.inputs.count)
            XCTAssert(transaction.inputs.allSatisfy(testTransaction.inputs.contains))
            XCTAssertEqual(transaction.memo, testTransaction.memo)
            cb(.success(SignedAvalancheTransaction(
                unsignedTransaction: transaction,
                credentials: []
            )))
        }
        avalanche.signatureProvider = signatureProvider
        api.send(
            amount: amount,
            assetID: assetID,
            to: toAddress,
            memo: memo,
            from: [fromAddress],
            change: testChangeAddress,
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
