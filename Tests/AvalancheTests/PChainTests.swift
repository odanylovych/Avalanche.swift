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
            chainId: api.info.chainId
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
        let fromAddressPath = testFromAddress.path
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
            XCTAssertEqual(extended.pathes, [fromAddress: fromAddressPath])
            XCTAssert(extended.utxoAddresses.first!.0 == SECP256K1Credential.self)
            XCTAssertEqual(extended.utxoAddresses.first!.1, [fromAddress])
            let transaction = extended.transaction as! AddDelegatorTransaction
            let testTransaction = try! AddDelegatorTransaction(
                networkID: self.api.networkID,
                blockchainID: self.api.info.blockchainID,
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
}
