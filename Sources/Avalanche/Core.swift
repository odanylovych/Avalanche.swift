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
    var signer: AvalancheSignatureProvider? { get set }
    var networkInfo: AvalancheNetworkInfoProvider { get }
    var settings: AvalancheSettings { get }
    var networkID: NetworkID { get set }
    
    init(
        url: URL,
        networkID: NetworkID,
        networkInfo: AvalancheNetworkInfoProvider,
        settings: AvalancheSettings
    )
    
    func getAPI<A: AvalancheApi>() throws -> A
    func createAPI<A: AvalancheApi>(networkID: NetworkID, hrp: String, info: A.Info) -> A
    
    func url(path: String) -> URL
}


extension AvalancheCore {
    public init(
        url: URL,
        networkID: NetworkID,
        hrp: String,
        apiInfo: AvalancheApiInfoProvider,
        settings: AvalancheSettings
    ) {
        let provider = AvalancheDefaultNetworkInfoProvider()
        let netInfo = AvalancheDefaultNetworkInfo(hrp: hrp, apiInfo: apiInfo)
        provider.setInfo(info: netInfo, for: networkID)
        self.init(url: url, networkID: networkID, networkInfo: provider, settings: settings)
        self.networkID = networkID
    }
    
}
