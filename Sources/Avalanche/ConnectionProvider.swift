//
//  ConnectionProvider.swift
//  
//
//  Created by Ostap Danylovych on 04.12.2021.
//

import Foundation
import RPC

public protocol AvalancheConnectionProvider {
    func singleShot(api: ApiConnection) -> SingleShotConnection
    func rpc(api: ApiConnection) -> Client
    func subscribableRPC(api: ApiConnection) -> PersistentConnection
}

public enum ApiConnection {
    case admin(path: String)
    case auth(path: String)
    case health(path: String)
    case info(path: String)
    case ipc(path: String)
    case keystore(path: String)
    case metrics(path: String)
    
    case xChain(path: String)
    case xChainVM(path: String)
    case pChain(path: String)
    case cChain(path: String)
    case cChainWS(path: String)
}
