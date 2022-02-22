//
//  Admin.swift
//  
//
//  Created by Daniel Leping on 27/12/2020.
//

import Foundation
import Serializable
#if !COCOAPODS
import RPC
#endif

public class AvalancheAdminApi: AvalancheApi {
    public let networkID: NetworkID
    public let chainID: ChainID
    private let service: Client

    public required init(avalanche: AvalancheCore, networkID: NetworkID, chainID: ChainID) {
        self.networkID = networkID
        self.chainID = chainID
        self.service = avalanche.connectionProvider.rpc(api: .admin)
    }
    
    public func alias(alias: String, endpoint: String,
                      cb: @escaping ApiCallback<Void>) {
        /// PARAMS STRUCT
        struct AliasParams: Encodable {
            let alias: String;
            let endpoint: String
        }
        /// CALL
        service.call(
            method: "admin.alias",
            params: AliasParams(alias: alias, endpoint: endpoint),
            SuccessResponse.self,
            SerializableValue.self
        ) { response in
            cb(response
                .mapError(AvalancheApiError.init)
                .flatMap { $0.toResult() })
        }
    }
    
    public func aliasChain(chain: BlockchainID, alias: String,
                           cb: @escaping ApiCallback<Void>) {
        struct AliasChainParams: Encodable {
            let chain: String
            let alias: String
        }
        service.call(
            method: "admin.aliasChain",
            params: AliasChainParams(chain: chain.cb58(), alias: alias),
            SuccessResponse.self,
            SerializableValue.self
        ) { response in
            cb(response
                .mapError(AvalancheApiError.init)
                .flatMap { $0.toResult() })
        }
    }
    
    public func lockProfile(cb: @escaping ApiCallback<Void>) {
        service.call(
            method: "admin.lockProfile",
            params: Nil.nil,
            SuccessResponse.self,
            SerializableValue.self
        ) { response in
            cb(response.mapError(AvalancheApiError.init).flatMap { $0.toResult() })
        }
    }
    
    public func memoryProfile(cb: @escaping ApiCallback<Void>) {
        service.call(
            method: "admin.memoryProfile",
            params: Nil.nil,
            SuccessResponse.self,
            SerializableValue.self
        ) { response in
            cb(response
                .mapError(AvalancheApiError.init)
                .flatMap { $0.toResult() })
        }
    }
    
    public func startCPUProfiler(cb: @escaping ApiCallback<Void>) {
        service.call(
            method: "admin.startCPUProfiler",
            params: Nil.nil,
            SuccessResponse.self,
            SerializableValue.self
        ) { response in
            cb(response
                .mapError(AvalancheApiError.init)
                .flatMap { $0.toResult() })
        }
    }
    public func stopCPUProfiler(cb: @escaping ApiCallback<Void>) {
        service.call(
            method: "admin.stopCPUProfiler",
            params: Nil.nil,
            SuccessResponse.self,
            SerializableValue.self
        ) { response in
            cb(response
                .mapError(AvalancheApiError.init)
                .flatMap { $0.toResult() })
        }
    }
}

extension AvalancheCore {
    public var admin: AvalancheAdminApi {
        try! self.getAPI(chainID: .alias("admin"))
    }
}
