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
    var apiPath: String { get }
}

public protocol AvalancheVMApi: AvalancheApi where Info: AvalancheVMApiInfo {
    associatedtype Keychain: AvalancheApiAddressManager
    
    var keychain: Keychain? { get }
    
    func getTransaction(id: TransactionID,
                        result: @escaping ApiCallback<SignedAvalancheTransaction>)
    
    func getUTXOs(
        addresses: [Keychain.Acct.Addr],
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

public protocol AvalancheVMApiInfo: AvalancheApiInfo {
    var blockchainID: BlockchainID { get }
    var alias: String? { get }
    var vm: String { get }
    
    var chainId: String { get }
}

extension AvalancheVMApiInfo {
    public var chainId: String {
        alias ?? blockchainID.cb58()
    }
}

public class AvalancheBaseVMApiInfo: AvalancheVMApiInfo {
    public let blockchainID: BlockchainID
    public let alias: String?
    public let vm: String
    
    public init(blockchainID: BlockchainID,
                alias: String?, vm: String)
    {
        self.blockchainID = blockchainID
        self.alias = alias
        self.vm = vm
    }
    
    public var apiPath: String {
        return "/ext/bc/\(chainId)"
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

