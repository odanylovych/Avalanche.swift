//
//  Core.swift
//  
//
//  Created by Yehor Popovych on 9/5/20.
//

import Foundation

public typealias AvalancheResponseCallback<R, E: Error> = (Result<R, E>) -> ()

public enum AvalancheApiSearchError: Error {
    case networkInfoNotFound(net: NetworkID)
    case apiInfoNotFound(net: NetworkID, apiId: String)
}

public protocol AvalancheCore: AnyObject {
    var networkID: NetworkID { get set }
    var networkInfo: AvalancheNetworkInfoProvider { get set }
    var settings: AvalancheSettings { get set }
    
    var addressManager: AvalancheAddressManager? { get set }
    var utxoCache: AvalancheUtxoCache? { get set }
    
    func getAPI<A: AvalancheApi>() throws -> A
    func createAPI<A: AvalancheApi>(networkID: NetworkID, hrp: String, info: A.Info) -> A
    
    func url(path: String) -> URL
}
