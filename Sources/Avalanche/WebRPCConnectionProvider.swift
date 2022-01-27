//
//  WebRPCConnectionProvider.swift
//  
//
//  Created by Ostap Danylovych on 06.12.2021.
//

import Foundation
#if !COCOAPODS
import RPC
import web3swift
#endif

extension ApiConnectionType {
    public var path: String {
        let path: String
        switch self {
        case .admin: path = "/admin"
        case .auth: path = "/auth"
        case .health: path = "/health"
        case .info: path = "/info"
        case .ipc: path = "/ipcs"
        case .keystore: path = "/keystore"
        case .metrics: path = "/admin"
        case .xChain(let alias, let blockchainID):
            path = "/bc/\(alias ?? blockchainID.cb58())"
        case .xChainVM(let vm): path = "/vm/\(vm)"
        case .pChain(let alias, let blockchainID):
            path = "/\(alias ?? blockchainID.cb58())"
        case .cChain(let alias, let blockchainID):
            path = "/bc/\(alias ?? blockchainID.cb58())/avax"
        case .cChainVM(let alias, let blockchainID):
            path = "/bc/\(alias ?? blockchainID.cb58())/rpc"
        }
        return "/ext\(path)"
    }
}

public struct WebRPCAvalancheConnectionProvider: AvalancheConnectionProvider {
    private let url: URL
    private let queue: DispatchQueue
    private let session: URLSession
    private let headers: [String: String]
    private let encoder: ContentEncoder
    private let decoder: ContentDecoder
    
    public init(
        url: URL,
        queue: DispatchQueue,
        session: URLSession,
        headers: [String: String],
        encoder: ContentEncoder,
        decoder: ContentDecoder
    ) {
        self.url = url
        self.queue = queue
        self.session = session
        self.headers = headers
        self.encoder = encoder
        self.decoder = decoder
    }
    
    public init(url: URL, settings: AvalancheSettings) {
        self.init(
            url: url,
            queue: settings.queue,
            session: settings.session,
            headers: settings.headers,
            encoder: settings.encoder,
            decoder: settings.decoder
        )
    }
    
    private func getUrl(for api: ApiConnectionType) -> URL {
        URL(string: api.path, relativeTo: url)!
    }
    
    private func getUrl(subscribable api: ApiConnectionType) -> URL? {
        switch api {
        case .cChainVM(let alias, let blockchainID):
            let path = "/ext/bc/\(alias ?? blockchainID.cb58())/ws"
            return URL(string: path, relativeTo: url)!
        default: return nil
        }
    }
    
    public func singleShot(api: ApiConnectionType) -> SingleShotConnection {
        HttpConnection(url: getUrl(for: api), queue: queue, headers: [:], session: session)
    }
    
    public func rpc(api: ApiConnectionType) -> Client {
        JsonRpc(.http(url: getUrl(for: api), session: session, headers: headers),
                queue: queue,
                encoder: encoder,
                decoder: decoder)
    }
    
    public func subscribableRPC(api: ApiConnectionType) -> Subscribable? {
        guard let url = getUrl(subscribable: api) else {
            return nil
        }
        return JsonRpc(.ws(url: url), queue: queue, encoder: encoder, decoder: decoder)
    }
}
