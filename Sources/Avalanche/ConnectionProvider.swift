//
//  ConnectionProvider.swift
//  
//
//  Created by Ostap Danylovych on 04.12.2021.
//

import Foundation
#if !COCOAPODS
import RPC
import web3swift
#endif

public typealias Subscribable = Client & Delegator

public protocol AvalancheConnectionProvider {
    func singleShot(api: ApiConnectionType) -> SingleShotConnection
    func rpc(api: ApiConnectionType) -> Client
    func subscribableRPC(api: ApiConnectionType) -> Subscribable?
}

public enum ApiConnectionType {
    case admin
    case auth
    case health
    case info
    case ipc
    case keystore
    case metrics
    
    case xChain(chainID: ChainID)
    case xChainVM(vm: String)
    case pChain(chainID: ChainID)
    case cChain(chainID: ChainID)
    case cChainVM(chainID: ChainID)
}
