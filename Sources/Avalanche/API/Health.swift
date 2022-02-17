//
//  Health.swift
//  
//
//  Created by Yehor Popovych on 10/26/20.
//

import Foundation
import Serializable
#if !COCOAPODS
import RPC
#endif

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
    private let service: Client
    
    public required init(avalanche: AvalancheCore, networkID: NetworkID) {
        self.networkID = networkID
        self.service = avalanche.connectionProvider.rpc(api: .health)
    }
    
    public func getLiveness(cb: @escaping ApiCallback<AvalancheLivenessResponse>) {
        service.call(
            method: "health.getLiveness",
            params: Nil.nil,
            AvalancheLivenessResponse.self,
            SerializableValue.self
        ) {
            cb($0.mapError(AvalancheApiError.init))
        }
    }
}

extension AvalancheCore {
    public var health: AvalancheHealthApi {
        try! self.getAPI()
    }
}
