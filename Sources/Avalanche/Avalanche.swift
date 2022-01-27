//
//  Avalanche.swift
//
//
//  Created by Yehor Popovych on 9/5/20.
//

import Foundation

public class Avalanche: AvalancheCore {
    private var _apis: [String: Any]
    private let _lock: NSRecursiveLock
    
    private var _networkID: NetworkID
    private var _settings: AvalancheSettings
    private var _signatureProvider: AvalancheSignatureProvider?
    private var _connectionProvider: AvalancheConnectionProvider
    
    public var networkID: NetworkID {
        get { _networkID }
        set {
            _lock.lock()
            _networkID = newValue
            _apis = [:]
            _lock.unlock()
        }
    }
    
    public var settings: AvalancheSettings {
        get { _settings }
        set {
            _lock.lock()
            _settings = newValue
            _apis = [:]
            _lock.unlock()
        }
    }
    
    public var signatureProvider: AvalancheSignatureProvider? {
        get { _signatureProvider }
        set {
            _lock.lock()
            _signatureProvider = newValue
            _apis = [:]
            _lock.unlock()
        }
    }
    
    public var connectionProvider: AvalancheConnectionProvider {
        get { _connectionProvider }
        set {
            _lock.lock()
            _connectionProvider = newValue
            _apis = [:]
            _lock.unlock()
        }
    }
    
    public init(networkID: NetworkID,
                settings: AvalancheSettings = AvalancheSettings(),
                signatureProvider: AvalancheSignatureProvider? = nil,
                connectionProvider: AvalancheConnectionProvider) {
        self._apis = [:]
        self._lock = NSRecursiveLock()
        self._networkID = networkID
        self._settings = settings
        self._signatureProvider = signatureProvider
        self._connectionProvider = connectionProvider
    }
    
    public func getAPI<API: AvalancheApi>() throws -> API {
        _lock.lock()
        defer { _lock.unlock() }
        
        if let api = _apis[API.id] as? API {
            return api
        }
        guard let netInfo = _settings.networkInfoProvider.info(for: networkID) else {
            throw AvalancheApiSearchError.networkInfoNotFound(net: networkID)
        }
        guard let info = netInfo.apiInfo.info(for: API.self) else {
            throw AvalancheApiSearchError.apiInfoNotFound(net: networkID, apiId: API.id)
        }
        let api: API = self.createAPI(networkID: networkID, hrp: netInfo.hrp, info: info)
        _apis[API.id] = api
        return api
    }
    
    public func createAPI<API: AvalancheApi>(networkID: NetworkID, hrp: String, info: API.Info) -> API {
        _lock.lock()
        defer { _lock.unlock() }
        return API(avalanche: self, networkID: networkID, hrp: hrp, info: info)
    }
}

extension Avalanche {
    public convenience init(url: URL, network: NetworkID) {
        self.init(networkID: network,
                  connectionProvider: WebRPCAvalancheConnectionProvider(url: url))
    }
}
