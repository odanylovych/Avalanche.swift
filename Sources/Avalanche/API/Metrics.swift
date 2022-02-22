//
//  Metrics.swift
//  
//
//  Created by Daniel Leping on 27/12/2020.
//

import Foundation
import Serializable
#if !COCOAPODS
import RPC
#endif

public class AvalancheMetricsApi: AvalancheApi {
    public let networkID: NetworkID
    public let chainID: ChainID
    private let connection: SingleShotConnection
    
    public required init(avalanche: AvalancheCore, networkID: NetworkID, chainID: ChainID) {
        self.networkID = networkID
        self.chainID = chainID
        self.connection = avalanche.connectionProvider.singleShot(api: .metrics)
    }
    
    public func getMetrics(cb: @escaping ApiCallback<String>) {
        connection.request(data: nil) { response in
            cb(response
                .mapError { .networkService(error: .connection(cause: $0)) }
                .flatMap { data in
                    guard let data = data else {
                        return .failure(.networkBodyIsEmpty)
                    }
                    guard let string = String(data: data, encoding: .utf8) else {
                        return .failure(.malformed(field: "body",
                                                   description: .decodeError))
                    }
                    return .success(string)
                }
            )
        }
    }
}

private extension String {
    static var decodeError: String {
        "Unable to decode Data to String"
    }
}

extension AvalancheCore {
    public var metrics: AvalancheMetricsApi {
        try! self.getAPI(chainID: .alias("metrics"))
    }
}
