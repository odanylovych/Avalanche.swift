//
//  Avalanche.swift
//
//
//  Created by Yehor Popovych on 9/5/20.
//

import Foundation

public class Avalanche: AvalancheCore {
    private var _apis: [String: AvalancheApi]
    private let _syncQueue: DispatchQueue
    
    public let networkID: NetworkID
    public let settings: AvalancheSettings
    public let signatureProvider: AvalancheSignatureProvider?
    public let connectionProvider: AvalancheConnectionProvider
    
    public init(networkID: NetworkID,
                settings: AvalancheSettings = AvalancheSettings(),
                connectionProvider: AvalancheConnectionProvider,
                signatureProvider: AvalancheSignatureProvider? = nil) {
        self._apis = [:]
        self._syncQueue = DispatchQueue(label: "Avalanche Sync Queue", target: .global(qos: .userInteractive))
        self.networkID = networkID
        self.settings = settings
        self.signatureProvider = signatureProvider
        self.connectionProvider = connectionProvider
    }
    
    public func _createAPI<API: AvalancheApi>(networkID: NetworkID, chainID: ChainID) throws -> API {
        return try API(avalanche: self, networkID: networkID, chainID: chainID)
    }
    
    public func getAPI<API: AvalancheApi>(chainID: ChainID) throws -> API {
        let apiId = chainID.value + "-" + API.id
        return try _syncQueue.sync {
            if let api = _apis[apiId] as? API {
                return api
            }
            let api: API = try self._createAPI(networkID: networkID, chainID: chainID)
            _apis[apiId] = api
            return api
        }
    }
    
    public func createAPI<API: AvalancheApi>(networkID: NetworkID, chainID: ChainID) throws -> API {
        return try _syncQueue.sync {
            return try self._createAPI(networkID: networkID, chainID: chainID)
        }
    }
}

extension Avalanche {
    public convenience init(url: URL,
                            networkID: NetworkID,
                            settings: AvalancheSettings = AvalancheSettings(),
                            signatureProvider: AvalancheSignatureProvider? = nil) {
        self.init(networkID: networkID,
                  settings: settings,
                  connectionProvider: WebRPCAvalancheConnectionProvider(url: url),
                  signatureProvider: signatureProvider)
    }
}
