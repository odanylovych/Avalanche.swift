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
    private var _networkInfoProvider: AvalancheNetworkInfoProvider
    private var _settings: AvalancheSettings
    private var _addressManager: AvalancheAddressManager?
    private var _utxoProvider: AvalancheUtxoProvider
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
    
    public var networkInfoProvider: AvalancheNetworkInfoProvider {
        get { _networkInfoProvider }
        set {
            _lock.lock()
            _networkInfoProvider = newValue
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
    
    public var addressManager: AvalancheAddressManager? {
        get { _addressManager }
        set {
            _lock.lock()
            _addressManager = newValue
            _apis = [:]
            _lock.unlock()
            _addressManager?.start(avalanche: self)
        }
    }
    
    public var utxoProvider: AvalancheUtxoProvider {
        get { _utxoProvider }
        set {
            _lock.lock()
            _utxoProvider = newValue
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
                networkInfo: AvalancheNetworkInfoProvider = AvalancheDefaultNetworkInfoProvider.default,
                settings: AvalancheSettings = .default,
                utxoProvider: AvalancheUtxoProvider = AvalancheDefaultUtxoProvider(),
                addressManager: AvalancheAddressManager? = nil,
                signatureProvider: AvalancheSignatureProvider? = nil,
                connectionProvider: AvalancheConnectionProvider) {
        self._apis = [:]
        self._lock = NSRecursiveLock()
        self._networkID = networkID
        self._addressManager = addressManager
        self._networkInfoProvider = networkInfo
        self._settings = settings
        self._utxoProvider = utxoProvider
        self._signatureProvider = signatureProvider
        self._connectionProvider = connectionProvider
        addressManager?.start(avalanche: self)
    }
    
    public func getAPI<API: AvalancheApi>() throws -> API {
        _lock.lock()
        defer { _lock.unlock() }
        
        if let api = _apis[API.id] as? API {
            return api
        }
        guard let netInfo = _networkInfoProvider.info(for: networkID) else {
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
    public convenience init(networkID: NetworkID,
                            networkInfo: AvalancheNetworkInfoProvider = AvalancheDefaultNetworkInfoProvider.default,
                            settings: AvalancheSettings = .default,
                            signer: AvalancheSignatureProvider,
                            connectionProvider: AvalancheConnectionProvider) {
        self.init(
            networkID: networkID,
            networkInfo: networkInfo, settings: settings,
            addressManager: AvalancheDefaultAddressManager(signer: signer),
            signatureProvider: signer,
            connectionProvider: connectionProvider
        )
    }
    
    public convenience init(networkID: NetworkID,
                            hrp: String, apiInfo: AvalancheApiInfoProvider,
                            settings: AvalancheSettings,
                            signer: AvalancheSignatureProvider,
                            connectionProvider: AvalancheConnectionProvider) {
        self.init(
            networkID: networkID, hrp: hrp,
            apiInfo: apiInfo, settings: settings,
            addressManager: AvalancheDefaultAddressManager(signer: signer),
            signer: signer,
            connectionProvider: connectionProvider
        )
    }
    
    public convenience init(networkID: NetworkID,
                            hrp: String, apiInfo: AvalancheApiInfoProvider,
                            settings: AvalancheSettings,
                            addressManager: AvalancheAddressManager? = nil,
                            signer: AvalancheSignatureProvider,
                            connectionProvider: AvalancheConnectionProvider) {
        let provider = AvalancheDefaultNetworkInfoProvider()
        let netInfo = AvalancheDefaultNetworkInfo(hrp: hrp, apiInfo: apiInfo)
        provider.setInfo(info: netInfo, for: networkID)
        self.init(networkID: networkID, networkInfo: provider, settings: settings, addressManager: addressManager, signatureProvider: signer, connectionProvider: connectionProvider)
    }
}
