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

public struct AvalancheAdminApiInfo: AvalancheApiInfo {
    public let apiPath: String = "/ext/admin"
}

public class AvalancheAdminApi: AvalancheApi {
    public typealias Info = AvalancheAdminApiInfo

    private let service: Client

    public required init(avalanche: AvalancheCore,
                         networkID: NetworkID,
                         hrp: String,
                         info: AvalancheAdminApiInfo) {
        let settings = avalanche.settings
        let url = avalanche.url(path: info.apiPath)
        
        self.service = JsonRpc(.http(url: url, session: settings.session, headers: settings.headers), queue: settings.queue, encoder: settings.encoder, decoder: settings.decoder)
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
        try! self.getAPI()
    }
}
