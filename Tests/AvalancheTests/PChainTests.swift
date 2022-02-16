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
    private let creationTxFee: UInt64 = 10_000_000
    private let txFee: UInt64 = 1_000_000
    
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
        let settings = AvalancheSettings(addressManagerProvider: addressManagerProvider, utxoProvider: utxoProvider)
        let avalanche = AvalancheCoreMock(settings: settings, connectionProvider: connectionProvider)
        avalanche.getAPIMock = avalanche.defaultGetAPIMock(for: .test)
        self.avalanche = avalanche
        testAccount = try! Account(
            pubKey: Data(hex: "0x02ccbf163222a621523a477389b2b6318b9c43b424bdf4b74340e9b45443cc0506")!,
            chainCode: Data(count: 32),
            path: try! Bip32Path.prefixAvalanche.appending(0, hard: true)
        )
        idIndex = 0
        addressIndex = 0
        avaxAssetID = newID(type: AssetID.self)
        testFromAddress = newAddress()
        testChangeAddress = newAddress().address
        testTransactionID = newID(type: TransactionID.self)
        let utxoTransactionID = newID(type: TransactionID.self)
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
    
    private var addressManagerProvider: AddressManagerProvider {
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
        return AddressManagerProviderMock(addressManager: addressManager)
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
    
    private func newID<T: ID>(type: T.Type) -> T {
        let id = T(data: Data(repeating: idIndex, count: T.size))!
        idIndex += 1
        return id
    }
    
    private func newAddress<API: AvalancheVMApi>(api: API) -> ExtendedAddress {
        let extended = try! testAccount.derive(
            index: addressIndex,
            change: false,
            hrp: api.hrp,
            chainId: api.chainID.value
        )
        addressIndex += 1
        return extended
    }
    
    private func newAddress() -> ExtendedAddress {
        newAddress(api: api)
    }
    
    func testAddDelegator() throws {
        let success = expectation(description: "success")
        let nodeID = newID(type: NodeID.self)
        let startTime = Date()
        let endTime = startTime + 1000
        let stakeAmount: UInt64 = 50_000_000
        let reward = newAddress().address
        let fromAddress = testFromAddress.address
        let toAddress = newAddress().address
        let memo = "memo".data(using: .utf8)!
        let utxo = UTXO(
            transactionID: newID(type: TransactionID.self),
            utxoIndex: 0,
            assetID: avaxAssetID,
            output: try StakeableLockedOutput(
                locktime: Date() + 100,
                transferableOutput: TransferableOutput(
                    assetID: newID(type: AssetID.self),
                    output: SECP256K1TransferOutput(
                        amount: 110_000_000,
                        locktime: Date(timeIntervalSince1970: 0),
                        threshold: 1,
                        addresses: [testFromAddress.address]
                    )
                )
            )
        )
        testUtxos.append(utxo)
        let lockedOutput = utxo.output as! StakeableLockedOutput
        let lockedOutputOutput = lockedOutput.transferableOutput.output
        let lockedOutputAmount = (lockedOutputOutput as! SECP256K1TransferOutput).amount
        let inputs = [
            TransferableInput(
                transactionID: utxo.transactionID,
                utxoIndex: utxo.utxoIndex,
                assetID: utxo.assetID,
                input: StakeableLockedInput(
                    locktime: lockedOutput.locktime,
                    transferableInput: TransferableInput(
                        transactionID: utxo.transactionID,
                        utxoIndex: utxo.utxoIndex,
                        assetID: utxo.assetID,
                        input: try SECP256K1TransferInput(
                            amount: lockedOutputAmount,
                            addressIndices: lockedOutput.getAddressIndices(for: [fromAddress])
                        )
                    )
                )
            )
        ]
        let outputs = [
            TransferableOutput(
                assetID: avaxAssetID,
                output: try StakeableLockedOutput(
                    locktime: lockedOutput.locktime,
                    transferableOutput: TransferableOutput(
                        assetID: avaxAssetID,
                        output: type(of: lockedOutputOutput).init(
                            amount: lockedOutputAmount - stakeAmount,
                            locktime: lockedOutputOutput.locktime,
                            threshold: lockedOutputOutput.threshold,
                            addresses: lockedOutputOutput.addresses
                        )
                    )
                )
            )
        ]
        let stakeOutputs = [
            TransferableOutput(
                assetID: avaxAssetID,
                output: try StakeableLockedOutput(
                    locktime: lockedOutput.locktime,
                    transferableOutput: TransferableOutput(
                        assetID: avaxAssetID,
                        output: type(of: lockedOutputOutput).init(
                            amount: stakeAmount,
                            locktime: lockedOutputOutput.locktime,
                            threshold: lockedOutputOutput.threshold,
                            addresses: lockedOutputOutput.addresses
                        )
                    )
                )
            )
        ]
        let signatureProvider = SignatureProviderMock()
        signatureProvider.signTransactionMock = { transaction, cb in
            let extended = transaction as! ExtendedAvalancheTransaction
            XCTAssertEqual(extended.extended, [fromAddress: self.testFromAddress])
            XCTAssert(extended.credential.first!.0 == SECP256K1Credential.self)
            XCTAssertEqual(extended.credential.first!.1, [fromAddress])
            let transaction = extended.transaction as! AddDelegatorTransaction
            self.api.getBlockchainID { res in
                let blockchainID = try! res.get()
                let testTransaction = try! AddDelegatorTransaction(
                    networkID: self.api.networkID,
                    blockchainID: blockchainID,
                    outputs: outputs,
                    inputs: inputs,
                    memo: memo,
                    validator: Validator(
                        nodeID: nodeID,
                        startTime: startTime,
                        endTime: endTime,
                        weight: stakeAmount
                    ),
                    stake: Stake(lockedOutputs: stakeOutputs),
                    rewardsOwner: SECP256K1OutputOwners(
                        locktime: Date(timeIntervalSince1970: 0),
                        threshold: 1,
                        addresses: [reward]
                    )
                )
                XCTAssertEqual(transaction, testTransaction)
                cb(.success(SignedAvalancheTransaction(
                    unsignedTransaction: transaction,
                    credentials: []
                )))
            }
        }
        avalanche.signatureProvider = signatureProvider
        api.addDelegator(
            nodeID: nodeID,
            startTime: startTime,
            endTime: endTime,
            stakeAmount: stakeAmount,
            reward: reward,
            from: [fromAddress],
            to: [toAddress],
            change: testChangeAddress,
            memo: memo,
            credentials: .account(testAccount)
        ) { res in
            let (transactionID, changeAddress) = try! res.get()
            XCTAssertEqual(transactionID, self.testTransactionID)
            XCTAssertEqual(changeAddress, self.testChangeAddress)
            success.fulfill()
        }
        wait(for: [success], timeout: 10)
    }
    
    func testAddValidator() throws {
        let success = expectation(description: "success")
        let nodeID = newID(type: NodeID.self)
        let startTime = Date()
        let endTime = startTime + 1000
        let stakeAmount: UInt64 = 50_000_000
        let reward = newAddress().address
        let fromAddress = testFromAddress.address
        let toAddress = newAddress().address
        let memo = "memo".data(using: .utf8)!
        let delegationFeeRate: Float = 0.0001
        let utxo = UTXO(
            transactionID: newID(type: TransactionID.self),
            utxoIndex: 0,
            assetID: avaxAssetID,
            output: try StakeableLockedOutput(
                locktime: Date() + 100,
                transferableOutput: TransferableOutput(
                    assetID: newID(type: AssetID.self),
                    output: SECP256K1TransferOutput(
                        amount: 110_000_000,
                        locktime: Date(timeIntervalSince1970: 0),
                        threshold: 1,
                        addresses: [testFromAddress.address]
                    )
                )
            )
        )
        testUtxos.append(utxo)
        let lockedOutput = utxo.output as! StakeableLockedOutput
        let lockedOutputOutput = lockedOutput.transferableOutput.output
        let lockedOutputAmount = (lockedOutputOutput as! SECP256K1TransferOutput).amount
        let inputs = [
            TransferableInput(
                transactionID: utxo.transactionID,
                utxoIndex: utxo.utxoIndex,
                assetID: utxo.assetID,
                input: StakeableLockedInput(
                    locktime: lockedOutput.locktime,
                    transferableInput: TransferableInput(
                        transactionID: utxo.transactionID,
                        utxoIndex: utxo.utxoIndex,
                        assetID: utxo.assetID,
                        input: try SECP256K1TransferInput(
                            amount: lockedOutputAmount,
                            addressIndices: lockedOutput.getAddressIndices(for: [fromAddress])
                        )
                    )
                )
            )
        ]
        let outputs = [
            TransferableOutput(
                assetID: avaxAssetID,
                output: try StakeableLockedOutput(
                    locktime: lockedOutput.locktime,
                    transferableOutput: TransferableOutput(
                        assetID: avaxAssetID,
                        output: type(of: lockedOutputOutput).init(
                            amount: lockedOutputAmount - stakeAmount,
                            locktime: lockedOutputOutput.locktime,
                            threshold: lockedOutputOutput.threshold,
                            addresses: lockedOutputOutput.addresses
                        )
                    )
                )
            )
        ]
        let stakeOutputs = [
            TransferableOutput(
                assetID: avaxAssetID,
                output: try StakeableLockedOutput(
                    locktime: lockedOutput.locktime,
                    transferableOutput: TransferableOutput(
                        assetID: avaxAssetID,
                        output: type(of: lockedOutputOutput).init(
                            amount: stakeAmount,
                            locktime: lockedOutputOutput.locktime,
                            threshold: lockedOutputOutput.threshold,
                            addresses: lockedOutputOutput.addresses
                        )
                    )
                )
            )
        ]
        let signatureProvider = SignatureProviderMock()
        signatureProvider.signTransactionMock = { transaction, cb in
            let extended = transaction as! ExtendedAvalancheTransaction
            XCTAssertEqual(extended.extended, [fromAddress: self.testFromAddress])
            XCTAssert(extended.credential.first!.0 == SECP256K1Credential.self)
            XCTAssertEqual(extended.credential.first!.1, [fromAddress])
            let transaction = extended.transaction as! AddValidatorTransaction
            self.api.getBlockchainID { res in
                let blockchainID = try! res.get()
                let testTransaction = try! AddValidatorTransaction(
                    networkID: self.api.networkID,
                    blockchainID: blockchainID,
                    outputs: outputs,
                    inputs: inputs,
                    memo: memo,
                    validator: Validator(
                        nodeID: nodeID,
                        startTime: startTime,
                        endTime: endTime,
                        weight: stakeAmount
                    ),
                    stake: Stake(lockedOutputs: stakeOutputs),
                    rewardsOwner: SECP256K1OutputOwners(
                        locktime: Date(timeIntervalSince1970: 0),
                        threshold: 1,
                        addresses: [reward]
                    ),
                    shares: UInt32(delegationFeeRate * 10_000)
                )
                XCTAssertEqual(transaction, testTransaction)
                cb(.success(SignedAvalancheTransaction(
                    unsignedTransaction: transaction,
                    credentials: []
                )))
            }
        }
        avalanche.signatureProvider = signatureProvider
        api.addValidator(
            nodeID: nodeID,
            startTime: startTime,
            endTime: endTime,
            stakeAmount: stakeAmount,
            reward: reward,
            delegationFeeRate: delegationFeeRate,
            from: [fromAddress],
            to: [toAddress],
            change: testChangeAddress,
            memo: memo,
            credentials: .account(testAccount)
        ) { res in
            let (transactionID, changeAddress) = try! res.get()
            XCTAssertEqual(transactionID, self.testTransactionID)
            XCTAssertEqual(changeAddress, self.testChangeAddress)
            success.fulfill()
        }
        wait(for: [success], timeout: 10)
    }
    
    func skipped_testAddSubnetValidator() throws {
        let success = expectation(description: "success")
        let nodeID = newID(type: NodeID.self)
        let subnetID = newID(type: BlockchainID.self)
        let startTime = Date()
        let endTime = startTime + 1000
        let weight: UInt64 = 50_000_000
        let fromAddress = testFromAddress.address
        let memo = "memo".data(using: .utf8)!
        let utxo = UTXO(
            transactionID: newID(type: TransactionID.self),
            utxoIndex: 0,
            assetID: avaxAssetID,
            output: try StakeableLockedOutput(
                locktime: Date() + 100,
                transferableOutput: TransferableOutput(
                    assetID: newID(type: AssetID.self),
                    output: SECP256K1TransferOutput(
                        amount: 110_000_000,
                        locktime: Date(timeIntervalSince1970: 0),
                        threshold: 1,
                        addresses: [testFromAddress.address]
                    )
                )
            )
        )
        testUtxos.append(utxo)
        let lockedOutput = utxo.output as! StakeableLockedOutput
        let lockedOutputOutput = lockedOutput.transferableOutput.output
        let lockedOutputAmount = (lockedOutputOutput as! SECP256K1TransferOutput).amount
        let inputs = [
            TransferableInput(
                transactionID: utxo.transactionID,
                utxoIndex: utxo.utxoIndex,
                assetID: utxo.assetID,
                input: StakeableLockedInput(
                    locktime: lockedOutput.locktime,
                    transferableInput: TransferableInput(
                        transactionID: utxo.transactionID,
                        utxoIndex: utxo.utxoIndex,
                        assetID: utxo.assetID,
                        input: try SECP256K1TransferInput(
                            amount: lockedOutputAmount,
                            addressIndices: lockedOutput.getAddressIndices(for: [fromAddress])
                        )
                    )
                )
            )
        ]
        let outputs = [
            TransferableOutput(
                assetID: avaxAssetID,
                output: try StakeableLockedOutput(
                    locktime: lockedOutput.locktime,
                    transferableOutput: TransferableOutput(
                        assetID: avaxAssetID,
                        output: type(of: lockedOutputOutput).init(
                            amount: weight,
                            locktime: lockedOutputOutput.locktime,
                            threshold: lockedOutputOutput.threshold,
                            addresses: lockedOutputOutput.addresses
                        )
                    )
                )
            ),
            TransferableOutput(
                assetID: avaxAssetID,
                output: try StakeableLockedOutput(
                    locktime: lockedOutput.locktime,
                    transferableOutput: TransferableOutput(
                        assetID: avaxAssetID,
                        output: type(of: lockedOutputOutput).init(
                            amount: lockedOutputAmount - weight,
                            locktime: lockedOutputOutput.locktime,
                            threshold: lockedOutputOutput.threshold,
                            addresses: lockedOutputOutput.addresses
                        )
                    )
                )
            )
        ]
        let signatureProvider = SignatureProviderMock()
        signatureProvider.signTransactionMock = { transaction, cb in
            let extended = transaction as! ExtendedAvalancheTransaction
            XCTAssertEqual(extended.extended, [fromAddress: self.testFromAddress])
            XCTAssert(extended.credential.first!.0 == SECP256K1Credential.self)
            XCTAssertEqual(extended.credential.first!.1, [fromAddress])
            let transaction = extended.transaction as! AddSubnetValidatorTransaction
            self.api.getBlockchainID { res in
                let blockchainID = try! res.get()
                let testTransaction = try! AddSubnetValidatorTransaction(
                    networkID: self.api.networkID,
                    blockchainID: blockchainID,
                    outputs: outputs,
                    inputs: inputs,
                    memo: memo,
                    validator: Validator(
                        nodeID: nodeID,
                        startTime: startTime,
                        endTime: endTime,
                        weight: weight
                    ),
                    subnetID: subnetID,
                    subnetAuth: SubnetAuth(signatureIndices: []) // TODO: verify signatureIndices
                )
                XCTAssertEqual(transaction, testTransaction)
                cb(.success(SignedAvalancheTransaction(
                    unsignedTransaction: transaction,
                    credentials: []
                )))
            }
        }
        avalanche.signatureProvider = signatureProvider
        api.addSubnetValidator(
            nodeID: nodeID,
            subnetID: subnetID,
            startTime: startTime,
            endTime: endTime,
            weight: weight,
            from: [fromAddress],
            change: testChangeAddress,
            memo: memo,
            credentials: .account(testAccount)
        ) { res in
            let (transactionID, changeAddress) = try! res.get()
            XCTAssertEqual(transactionID, self.testTransactionID)
            XCTAssertEqual(changeAddress, self.testChangeAddress)
            success.fulfill()
        }
        wait(for: [success], timeout: 10)
    }
    
    func testCreateSubnet() throws {
        let success = expectation(description: "success")
        let fromAddress = testFromAddress.address
        let memo = "memo".data(using: .utf8)!
        let controlKeys = [newAddress().address]
        let threshold: UInt32 = 1
        let output = utxoForInput.output as! SECP256K1TransferOutput
        let inputs = [
            TransferableInput(
                transactionID: utxoForInput.transactionID,
                utxoIndex: utxoForInput.utxoIndex,
                assetID: utxoForInput.assetID,
                input: try SECP256K1TransferInput(
                    amount: output.amount,
                    addressIndices: output.getAddressIndices(for: [fromAddress])
                )
            )
        ]
        let fee = creationTxFee
        let outputs = [
            TransferableOutput(
                assetID: avaxAssetID,
                output: try SECP256K1TransferOutput(
                    amount: output.amount - fee,
                    locktime: Date(timeIntervalSince1970: 0),
                    threshold: 1,
                    addresses: [testChangeAddress]
                )
            )
        ]
        let signatureProvider = SignatureProviderMock()
        signatureProvider.signTransactionMock = { transaction, cb in
            let extended = transaction as! ExtendedAvalancheTransaction
            XCTAssertEqual(extended.extended, [fromAddress: self.testFromAddress])
            XCTAssert(extended.credential.first!.0 == SECP256K1Credential.self)
            XCTAssertEqual(extended.credential.first!.1, [fromAddress])
            let transaction = extended.transaction as! CreateSubnetTransaction
            self.api.getBlockchainID { res in
                let blockchainID = try! res.get()
                let testTransaction = try! CreateSubnetTransaction(
                    networkID: self.api.networkID,
                    blockchainID: blockchainID,
                    outputs: outputs,
                    inputs: inputs,
                    memo: memo,
                    rewardsOwner: SECP256K1OutputOwners(
                        locktime: Date(timeIntervalSince1970: 0),
                        threshold: threshold,
                        addresses: [fromAddress]
                    )
                )
                XCTAssertEqual(transaction, testTransaction)
                cb(.success(SignedAvalancheTransaction(
                    unsignedTransaction: transaction,
                    credentials: []
                )))
            }
        }
        avalanche.signatureProvider = signatureProvider
        api.createSubnet(
            controlKeys: controlKeys,
            threshold: threshold,
            from: [fromAddress],
            change: testChangeAddress,
            memo: memo,
            credentials: .account(testAccount)
        ) { res in
            let (transactionID, changeAddress) = try! res.get()
            XCTAssertEqual(transactionID, self.testTransactionID)
            XCTAssertEqual(changeAddress, self.testChangeAddress)
            success.fulfill()
        }
        wait(for: [success], timeout: 10)
    }
    
    func testExportAVAX() throws {
        let success = expectation(description: "success")
        let toChain = avalanche.xChain
        let toAddress = newAddress(api: toChain).address
        let amount: UInt64 = 50_000_000
        let fromAddress = testFromAddress.address
        let memo = "memo".data(using: .utf8)!
        let output = utxoForInput.output as! SECP256K1TransferOutput
        let inputs = [
            TransferableInput(
                transactionID: utxoForInput.transactionID,
                utxoIndex: utxoForInput.utxoIndex,
                assetID: utxoForInput.assetID,
                input: try SECP256K1TransferInput(
                    amount: output.amount,
                    addressIndices: output.getAddressIndices(for: [fromAddress])
                )
            )
        ]
        let fee = txFee
        let outputs = [
            TransferableOutput(
                assetID: avaxAssetID,
                output: try SECP256K1TransferOutput(
                    amount: output.amount - amount - fee,
                    locktime: Date(timeIntervalSince1970: 0),
                    threshold: 1,
                    addresses: [testChangeAddress]
                )
            )
        ]
        let exportOutputs = [
            TransferableOutput(
                assetID: avaxAssetID,
                output: try SECP256K1TransferOutput(
                    amount: amount,
                    locktime: Date(timeIntervalSince1970: 0),
                    threshold: 1,
                    addresses: [toAddress]
                )
            )
        ]
        let signatureProvider = SignatureProviderMock()
        signatureProvider.signTransactionMock = { transaction, cb in
            let extended = transaction as! ExtendedAvalancheTransaction
            XCTAssertEqual(extended.extended, [fromAddress: self.testFromAddress])
            XCTAssert(extended.credential.first!.0 == SECP256K1Credential.self)
            XCTAssertEqual(extended.credential.first!.1, [fromAddress])
            let transaction = extended.transaction as! ExportTransaction
            self.api.getBlockchainID { res in
                let blockchainID = try! res.get()
                self.api.blockchainIDs(toChain.chainID) { res in
                    let destinationChain = try! res.get()
                    let testTransaction = try! ExportTransaction(
                        networkID: self.api.networkID,
                        blockchainID: blockchainID,
                        outputs: outputs,
                        inputs: inputs,
                        memo: memo,
                        destinationChain: destinationChain,
                        transferableOutputs: exportOutputs
                    )
                    XCTAssertEqual(transaction, testTransaction)
                    cb(.success(SignedAvalancheTransaction(
                        unsignedTransaction: transaction,
                        credentials: []
                    )))
                }
            }
        }
        avalanche.signatureProvider = signatureProvider
        api.exportAVAX(
            to: toAddress,
            amount: amount,
            from: [fromAddress],
            change: testChangeAddress,
            memo: memo,
            credentials: .account(testAccount)
        ) { res in
            let (transactionID, changeAddress) = try! res.get()
            XCTAssertEqual(transactionID, self.testTransactionID)
            XCTAssertEqual(changeAddress, self.testChangeAddress)
            success.fulfill()
        }
        wait(for: [success], timeout: 10)
    }
    
    func testImportAVAX() throws {
        let success = expectation(description: "success")
        let fromAddress = testFromAddress.address
        let toAddress = newAddress().address
        let memo = "memo".data(using: .utf8)!
        let testSourceChain = newID(type: BlockchainID.self)
        let output = utxoForInput.output as! SECP256K1TransferOutput
        let inputs = [TransferableInput]()
        let fee = txFee
        let outputs = [
            TransferableOutput(
                assetID: avaxAssetID,
                output: try type(of: output).init(
                    amount: output.amount - fee,
                    locktime: Date(timeIntervalSince1970: 0),
                    threshold: 1,
                    addresses: [toAddress]
                )
            )
        ]
        let importInputs = [
            TransferableInput(
                transactionID: utxoForInput.transactionID,
                utxoIndex: utxoForInput.utxoIndex,
                assetID: utxoForInput.assetID,
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
        let settings = avalanche.settings
        avalanche.settings = AvalancheSettings(queue: settings.queue,
                                               networkInfoProvider: settings.networkInfoProvider,
                                               addressManagerProvider: settings.addressManagerProvider,
                                               utxoProvider: utxoProvider,
                                               encoderDecoderProvider: settings.encoderDecoderProvider)
        let signatureProvider = SignatureProviderMock()
        signatureProvider.signTransactionMock = { transaction, cb in
            let extended = transaction as! ExtendedAvalancheTransaction
            XCTAssertEqual(extended.extended, [fromAddress: self.testFromAddress])
            XCTAssert(extended.credential.first!.0 == SECP256K1Credential.self)
            XCTAssertEqual(extended.credential.first!.1, [fromAddress])
            let transaction = extended.transaction as! ImportTransaction
            self.api.getBlockchainID { res in
                let blockchainID = try! res.get()
                let testTransaction = try! ImportTransaction(
                    networkID: self.api.networkID,
                    blockchainID: blockchainID,
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
        }
        avalanche.signatureProvider = signatureProvider
        api.importAVAX(
            from: [fromAddress],
            to: toAddress,
            change: testChangeAddress,
            source: testSourceChain,
            memo: memo,
            credentials: .account(testAccount)
        ) { res in
            let (transactionID, changeAddress) = try! res.get()
            XCTAssertEqual(transactionID, self.testTransactionID)
            XCTAssertEqual(changeAddress, self.testChangeAddress)
            success.fulfill()
        }
        wait(for: [success], timeout: 10)
    }
    
}
