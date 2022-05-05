//
//  Core.swift
//  
//
//  Created by Yehor Popovych on 9/5/20.
//

import Foundation

public typealias AvalancheResponseCallback<R, E: Error> = (Result<R, E>) -> ()

public protocol AvalancheCore: AnyObject {
    var networkID: NetworkID { get set }
    var settings: AvalancheSettings { get set }
    var signatureProvider: AvalancheSignatureProvider? { get set }
    var connectionProvider: AvalancheConnectionProvider { get set }
    
    func getAPI<A: AvalancheApi>(chainID: ChainID) throws -> A
    func createAPI<A: AvalancheApi>(networkID: NetworkID, chainID: ChainID) -> A
}

public struct AvalancheConstants {
    public static let avaxAssetAlias = "AVAX"
}
