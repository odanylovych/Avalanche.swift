//
//  Avalanche.swift
//
//
//  Created by Yehor Popovych on 9/5/20.
//

import Foundation

public class Avalanche: AvalancheCore {
    private var apis: [String: Any]
    private let lock: NSRecursiveLock
    private let _url: URL
    
    public var networkID: NetworkID {
        willSet { lock.lock() }
        didSet { lock.unlock(); clearApis() }
    }
    
    public var networkInfo: AvalancheNetworkInfoProvider {
        willSet { lock.lock() }
        didSet { lock.unlock(); clearApis() }
    }
    
    public var settings: AvalancheSettings {
        willSet { lock.lock() }
        didSet { lock.unlock(); clearApis() }
    }
    
    public var addressManager: AvalancheAddressManager? {
        willSet { lock.lock() }
        didSet { lock.unlock(); clearApis() }
    }
    
    public var utxoCache: AvalancheUtxoCache? {
        willSet { lock.lock() }
        didSet { lock.unlock(); clearApis() }
    }
    
    public init(url: URL, networkID: NetworkID,
                networkInfo: AvalancheNetworkInfoProvider = AvalancheDefaultNetworkInfoProvider.default,
                settings: AvalancheSettings = .default,
                addressManager: AvalancheAddressManager? = nil) {
        self._url = url
        self.apis = [:]
        self.lock = NSRecursiveLock()
        self.networkID = networkID
        self.addressManager = addressManager
        self.networkInfo = networkInfo
        self.settings = settings
    }
    
    public func getAPI<API: AvalancheApi>() throws -> API {
        lock.lock()
        defer { lock.unlock() }
        
        if let api = self.apis[API.id] as? API {
            return api
        }
        guard let netInfo = self.networkInfo.info(for: networkID) else {
            throw AvalancheApiSearchError.networkInfoNotFound(net: networkID)
        }
        guard let info = netInfo.apiInfo.info(for: API.self) else {
            throw AvalancheApiSearchError.apiInfoNotFound(net: networkID, apiId: API.id)
        }
        let api: API = self.createAPI(networkID: networkID, hrp: netInfo.hrp, info: info)
        self.apis[API.id] = api
        return api
    }
    
    public func createAPI<API: AvalancheApi>(networkID: NetworkID, hrp: String, info: API.Info) -> API {
        lock.lock()
        defer { lock.unlock() }
        return API(avalanche: self, networkID: networkID, hrp: hrp, info: info)
    }
    
    public func url(path: String) -> URL {
        URL(string: path, relativeTo: _url)!
    }
    
    private func clearApis() {
        lock.lock()
        defer { lock.unlock() }
        apis = [:]
    }
}

extension Avalanche {
    public convenience init(url: URL, networkID: NetworkID,
                            networkInfo: AvalancheNetworkInfoProvider = AvalancheDefaultNetworkInfoProvider.default,
                            settings: AvalancheSettings = .default,
                            signer: AvalancheSignatureProvider) {
        self.init(
            url: url, networkID: networkID,
            networkInfo: networkInfo, settings: settings,
            addressManager: AvalancheDefaultAddressManager(
                signer: signer, queue: settings.queue
            )
        )
    }
    
    public convenience init(url: URL, networkID: NetworkID,
                            hrp: String, apiInfo: AvalancheApiInfoProvider,
                            settings: AvalancheSettings,
                            signer: AvalancheSignatureProvider) {
        self.init(
            url: url, networkID: networkID, hrp: hrp,
            apiInfo: apiInfo, settings: settings,
            addressManager: AvalancheDefaultAddressManager(
                signer: signer, queue: settings.queue
            )
        )
    }
    
    public convenience init(url: URL, networkID: NetworkID,
                            hrp: String, apiInfo: AvalancheApiInfoProvider,
                            settings: AvalancheSettings,
                            addressManager: AvalancheAddressManager? = nil) {
        let provider = AvalancheDefaultNetworkInfoProvider()
        let netInfo = AvalancheDefaultNetworkInfo(hrp: hrp, apiInfo: apiInfo)
        provider.setInfo(info: netInfo, for: networkID)
        self.init(url: url, networkID: networkID, networkInfo: provider, settings: settings, addressManager: addressManager)
    }
}
