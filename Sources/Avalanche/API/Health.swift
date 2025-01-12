//
//  Health.swift
//  
//
//  Created by Yehor Popovych on 10/26/20.
//

import Foundation
import Serializable
import JsonRPC

public struct AvalancheLivenessResponse: Decodable {
    public struct Check: Decodable {
        public let message: Dictionary<String, SerializableValue>?
        public let error: Dictionary<String, SerializableValue>?
        public let timestamp: Date
        public let duration: UInt64
        public let contiguousFailures: UInt32
        public let timeOfFirstFailure: Date?
    }
    
    public let healthy: Bool
    public let checks: Dictionary<String, Check>
}

public class AvalancheHealthApi: AvalancheApi {
    public let networkID: NetworkID
    public let chainID: ChainID
    private let service: Client
    
    public required init(avalanche: AvalancheCore, networkID: NetworkID, chainID: ChainID) {
        self.networkID = networkID
        self.chainID = chainID
        self.service = avalanche.connectionProvider.rpc(api: .health)
    }
    
    public func getLiveness(cb: @escaping ApiCallback<AvalancheLivenessResponse>) {
        service.call(
            method: "health.getLiveness",
            params: Params(),
            AvalancheLivenessResponse.self,
            SerializableValue.self
        ) {
            cb($0.mapError(AvalancheApiError.init))
        }
    }
}

extension AvalancheCore {
    public var health: AvalancheHealthApi {
        try! self.getAPI(chainID: .alias("health"))
    }
}
