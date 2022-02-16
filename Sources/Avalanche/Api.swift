//
//  Api.swift
//  
//
//  Created by Yehor Popovych on 9/5/20.
//

import Foundation

public protocol AvalancheApi {
    associatedtype Info: AvalancheApiInfo
    
    var networkID: NetworkID { get }
    var hrp: String { get }
    var info: Info { get }
    
    init(avalanche: AvalancheCore, networkID: NetworkID, hrp: String, info: Info)
    
    static var id: String { get }
}

extension AvalancheApi {
    public static var id: String {
        return String(describing: self)
    }
}

public protocol AvalancheApiInfo {
}

public protocol AvalancheVMApi: AvalancheApi where Info: AvalancheVMApiInfo {
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
        encoding: AvalancheEncoding?,
        _ cb: @escaping ApiCallback<(
            fetched: UInt32,
            utxos: [UTXO],
            endIndex: UTXOIndex,
            encoding: AvalancheEncoding
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

public protocol AvalancheVMApiInfo: AvalancheApiInfo {
    var blockchainID: BlockchainID { get }
}

public class AvalancheBaseVMApiInfo: AvalancheVMApiInfo {
    public let blockchainID: BlockchainID
    
    public init(blockchainID: BlockchainID)
    {
        self.blockchainID = blockchainID
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

