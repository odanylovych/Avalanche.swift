//
//  Api.swift
//  
//
//  Created by Yehor Popovych on 9/5/20.
//

import Foundation

public protocol AvalancheApi {
    var networkID: NetworkID { get }
    var chainID: ChainID { get }
    
    static var id: String { get }
    
    init(avalanche: AvalancheCore, networkID: NetworkID, chainID: ChainID) throws
}

extension AvalancheApi {
    public static var id: String { return String(describing: self) }
}

public protocol AvalancheVMApi: AvalancheApi {
    associatedtype Keychain: AvalancheApiAddressManager
    
    var chainID: ChainID { get }
    var keychain: Keychain? { get }
    
    func getTransaction(id: TransactionID,
                        result: @escaping ApiCallback<SignedAvalancheTransaction>)
    
    func getUTXOs(
        addresses: [Address],
        limit: UInt32?,
        startIndex: UTXOIndex?,
        sourceChain: BlockchainID?,
        _ cb: @escaping ApiCallback<(
            fetched: UInt32,
            utxos: [UTXO],
            endIndex: UTXOIndex,
            encoding: ApiDataEncoding
        )>
    )
}

public enum ChainID: Hashable {
    case alias(String)
    case blockchainID(BlockchainID)
    
    public init(_ value: String) {
        guard let blockchainID = BlockchainID(cb58: value) else {
            self = .alias(value)
            return
        }
        self = .blockchainID(blockchainID)
    }
    
    public var value: String {
        switch self {
        case .alias(let alias):
            return alias
        case .blockchainID(let blockchainID):
            return blockchainID.cb58()
        }
    }
}

public enum AvalancheVmApiCredentials: Equatable, Hashable {
    case password(username: String, password: String)
    case account(Account)
    
    public init(_ account: Account) {
        self = .account(account)
    }
    
    public init(_ username: String, _ password: String) {
        self = .password(username: username, password: password)
    }
    
    public var account: Account? {
        guard case .account(let acc) = self else {
            return nil
        }
        return acc
    }
    
    public var password: (username: String, password: String)? {
        guard case .password(username: let user, password: let pwd) = self else {
            return nil
        }
        return (user, pwd)
    }
}

