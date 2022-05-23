//
//  Core.swift
//  
//
//  Created by Yehor Popovych on 9/5/20.
//

import Foundation

public typealias AvalancheResponseCallback<R, E: Error> = (Result<R, E>) -> ()

public protocol AvalancheCore: AnyObject {
    var networkID: NetworkID { get }
    var settings: AvalancheSettings { get }
    var signatureProvider: AvalancheSignatureProvider? { get }
    var connectionProvider: AvalancheConnectionProvider { get }
    
    func getAPI<A: AvalancheApi>(chainID: ChainID) throws -> A
    func createAPI<A: AvalancheApi>(networkID: NetworkID, chainID: ChainID) throws -> A
}

public struct AvalancheConstants {
    public static let avaxAssetAlias = "AVAX"
}
