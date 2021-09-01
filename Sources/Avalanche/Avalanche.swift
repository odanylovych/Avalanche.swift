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
    public let settings: AvalancheSettings
    
    public var signer: AvalancheSignatureProvider? {
        willSet { lock.lock() }
        didSet { lock.unlock(); clearApis() }
    }
    
    public var networkInfo: AvalancheNetworkInfoProvider {
        willSet { lock.lock() }
        didSet { lock.unlock(); clearApis() }
    }
    
    public var networkID: NetworkID {
        willSet { lock.lock() }
        didSet { lock.unlock(); clearApis() }
    }
    
    public required init(url: URL, networkID: NetworkID, networkInfo: AvalancheNetworkInfoProvider = AvalancheDefaultNetworkInfoProvider.default, settings: AvalancheSettings = .default) {
        self._url = url
        self.apis = [:]
        self.networkID = networkID
        self.signer = nil
        self.networkInfo = networkInfo
        self.settings = settings
        self.lock = NSRecursiveLock()
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
