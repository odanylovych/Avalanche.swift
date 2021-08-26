//
//  Core.swift
//  
//
//  Created by Yehor Popovych on 9/5/20.
//

import Foundation

public typealias AvalancheResponseCallback<R, E: Error> = (Result<R, E>) -> ()

public enum AvalancheApiSearchError: Error {
    case networkInfoNotFound(net: AvalancheNetwork)
    case apiInfoNotFound(net: AvalancheNetwork, apiId: String)
}

public protocol AvalancheCore: AnyObject {
    var signer: AvalancheSignatureProvider? { get set }
    var networkInfo: AvalancheNetworkInfoProvider { get }
    var settings: AvalancheSettings { get }
    var network: AvalancheNetwork { get set }
    
    init(
        url: URL,
        network: AvalancheNetwork,
        networkInfo: AvalancheNetworkInfoProvider,
        settings: AvalancheSettings
    )
    
    func getAPI<A: AvalancheApi>() throws -> A
    func createAPI<A: AvalancheApi>(network: AvalancheNetwork, hrp: String, info: A.Info) -> A
    
    func url(path: String) -> URL
}


extension AvalancheCore {
    public init(
        url: URL,
        network: AvalancheNetwork,
        hrp: String,
        apiInfo: AvalancheApiInfoProvider,
        settings: AvalancheSettings
    ) {
        let provider = AvalancheDefaultNetworkInfoProvider()
        let netInfo = AvalancheDefaultNetworkInfo(hrp: hrp, apiInfo: apiInfo)
        provider.setInfo(info: netInfo, for: network)
        self.init(url: url, network: network, networkInfo: provider, settings: settings)
        self.network = network
    }
    
}
