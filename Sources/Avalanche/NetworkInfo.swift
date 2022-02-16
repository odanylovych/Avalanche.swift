//
//  NetworkInfo.swift
//  
//
//  Created by Yehor Popovych on 10/14/20.
//

import Foundation

public protocol AvalancheNetworkInfo {
    var hrp: String { get }
}

public protocol AvalancheNetworkInfoProvider {
    func info(for net: NetworkID) -> AvalancheNetworkInfo?
    func setInfo(info: AvalancheNetworkInfo, for net: NetworkID)
}

public class AvalancheDefaultNetworkInfo: AvalancheNetworkInfo {
    public let hrp: String
    
    public init(hrp: String) {
        self.hrp = hrp
    }
}

public class AvalancheDefaultNetworkInfoProvider: AvalancheNetworkInfoProvider {
    private var infos: Dictionary<NetworkID, AvalancheNetworkInfo>
    
    public init(infos: Dictionary<NetworkID, AvalancheNetworkInfo> = [:]) {
        self.infos = infos
    }
    
    public func info(for net: NetworkID) -> AvalancheNetworkInfo? {
        return infos[net]
    }
    
    public func setInfo(info: AvalancheNetworkInfo, for net: NetworkID) {
        infos[net] = info
    }
    
    public static let `default`: AvalancheNetworkInfoProvider = {
        // TODO: Fill Network Info table.
        // Example in JS:
        // https://github.com/ava-labs/avalanchejs/blob/master/src/utils/constants.ts
        let provider = AvalancheDefaultNetworkInfoProvider()
        
        // NetworkID.manhattan
        provider.setInfo(info: manhattanNetInfo(), for: .manhattan)
        // NetworkID.main || NetworkID.avalanche
        provider.setInfo(info: avalancheNetInfo(), for: .avalanche)
        // NetworkID.test || NetworkID.fuji
        provider.setInfo(info: fujiNetInfo(), for: .fuji)
        
        return provider
    }()
    
    // NetworkID.manhattan
    private static func manhattanNetInfo() -> AvalancheDefaultNetworkInfo {
        return AvalancheDefaultNetworkInfo(hrp: "custom")
    }

    // NetworkID.main || NetworkID.avalanche
    private static func avalancheNetInfo() -> AvalancheDefaultNetworkInfo {
        return AvalancheDefaultNetworkInfo(hrp: "avax")
    }

    // NetworkID.test || NetworkID.fuji
    private static func fujiNetInfo() -> AvalancheDefaultNetworkInfo {
        return AvalancheDefaultNetworkInfo(hrp: "fuji")
    }
}
