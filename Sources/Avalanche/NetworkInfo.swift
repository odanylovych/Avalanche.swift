//
//  NetworkInfo.swift
//  
//
//  Created by Yehor Popovych on 10/14/20.
//

import Foundation

public protocol AvalancheApiInfoProvider {
    func info<A: AvalancheApi>(for: A.Type) -> A.Info?
    func setInfo<A: AvalancheApi>(info: A.Info, for: A.Type)
}

public protocol AvalancheNetworkInfo {
    var hrp: String { get }
    var apiInfo: AvalancheApiInfoProvider { get }
}

public protocol AvalancheNetworkInfoProvider {
    func info(for net: NetworkID) -> AvalancheNetworkInfo?
    func setInfo(info: AvalancheNetworkInfo, for net: NetworkID)
}

public class AvalancheDefaultApiInfoProvider: AvalancheApiInfoProvider {
    private var infos: Dictionary<String, AvalancheApiInfo>
    
    public init(infos: Dictionary<String, AvalancheApiInfo> = [:]) {
        self.infos = infos
    }
    
    public func info<A: AvalancheApi>(for: A.Type) -> A.Info? {
        return infos[A.id] as? A.Info
    }
    
    public func setInfo<A: AvalancheApi>(info: A.Info, for: A.Type) {
        infos[A.id] = info
    }
}

public class AvalancheDefaultNetworkInfo: AvalancheNetworkInfo {
    public let hrp: String
    public let apiInfo: AvalancheApiInfoProvider
    
    public init(hrp: String, apiInfo: AvalancheApiInfoProvider) {
        self.hrp = hrp
        self.apiInfo = apiInfo
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
    
    private static func addNonVmApis(to info: AvalancheDefaultApiInfoProvider) {
        info.setInfo(info: AvalancheInfoApiInfo(), for: AvalancheInfoApi.self)
        info.setInfo(info: AvalancheHealthApiInfo(), for: AvalancheHealthApi.self)
        info.setInfo(info: AvalancheMetricsApiInfo(), for: AvalancheMetricsApi.self)
        info.setInfo(info: AvalancheAdminApiInfo(), for: AvalancheAdminApi.self)
        info.setInfo(info: AvalancheAuthApiInfo(), for: AvalancheAuthApi.self)
        info.setInfo(info: AvalancheIPCApiInfo(), for: AvalancheIPCApi.self)
        info.setInfo(info: AvalancheKeystoreApiInfo(), for: AvalancheKeystoreApi.self)
    }
    
    // NetworkID.manhattan
    private static func manhattanNetInfo() -> AvalancheDefaultNetworkInfo {
        let netApis = AvalancheDefaultApiInfoProvider()
        addNonVmApis(to: netApis)
        netApis.setInfo(
            info: AvalancheXChainApi.Info(
                blockchainID: BlockchainID(cb58: "2vrXWHgGxh5n3YsLHMV16YVVJTpT4z45Fmb4y3bL6si8kLCyg9")!
            ),
            for: AvalancheXChainApi.self
        )
        netApis.setInfo(
            info: AvalancheCChainApi.Info(
                blockchainID: BlockchainID(cb58: "2fFZQibQXcd6LTE4rpBPBAkLVXFE91Kit8pgxaBG1mRnh5xqbb")!
            ),
            for: AvalancheCChainApi.self
        )
        netApis.setInfo(
            info: AvalanchePChainApi.Info(
                blockchainID: BlockchainID(cb58: "11111111111111111111111111111111LpoYY")!
            ),
            for: AvalanchePChainApi.self
        )
        return AvalancheDefaultNetworkInfo(hrp: "custom", apiInfo: netApis)
    }

    // NetworkID.main || NetworkID.avalanche
    private static func avalancheNetInfo() -> AvalancheDefaultNetworkInfo {
        let netApis = AvalancheDefaultApiInfoProvider()
        addNonVmApis(to: netApis)
        netApis.setInfo(
            info: AvalancheXChainApi.Info(
                blockchainID: BlockchainID(cb58: "2oYMBNV4eNHyqk2fjjV5nVQLDbtmNJzq5s3qs3Lo6ftnC6FByM")!
            ),
            for: AvalancheXChainApi.self
        )
        netApis.setInfo(
            info: AvalancheCChainApi.Info(
                blockchainID: BlockchainID(cb58: "2q9e4r6Mu3U68nU1fYjgbR6JvwrRx36CohpAX5UQxse55x1Q5")!
            ),
            for: AvalancheCChainApi.self
        )
        netApis.setInfo(
            info: AvalanchePChainApi.Info(
                blockchainID: BlockchainID(cb58: "11111111111111111111111111111111LpoYY")!
            ),
            for: AvalanchePChainApi.self
        )
        return AvalancheDefaultNetworkInfo(hrp: "avax", apiInfo: netApis)
    }

    // NetworkID.test || NetworkID.fuji
    private static func fujiNetInfo() -> AvalancheDefaultNetworkInfo {
        let netApis = AvalancheDefaultApiInfoProvider()
        addNonVmApis(to: netApis)
        netApis.setInfo(
            info: AvalancheXChainApi.Info(
                blockchainID: BlockchainID(cb58: "2JVSBoinj9C2J33VntvzYtVJNZdN2NKiwwKjcumHUWEb5DbBrm")!
            ),
            for: AvalancheXChainApi.self
        )
        netApis.setInfo(
            info: AvalancheCChainApi.Info(
                blockchainID: BlockchainID(cb58: "yH8D7ThNJkxmtkuv2jgBa4P1Rn3Qpr4pPr7QYNfcdoS6k6HWp")!
            ),
            for: AvalancheCChainApi.self
        )
        netApis.setInfo(
            info: AvalanchePChainApi.Info(
                blockchainID: BlockchainID(cb58: "11111111111111111111111111111111LpoYY")!
            ),
            for: AvalanchePChainApi.self
        )
        return AvalancheDefaultNetworkInfo(hrp: "fuji", apiInfo: netApis)
    }
}
