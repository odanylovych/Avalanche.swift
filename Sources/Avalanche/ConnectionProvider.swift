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
    case xChain(path: String)
    case xChainVm(path: String)
}
