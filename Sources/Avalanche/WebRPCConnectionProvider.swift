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
        case .xChain(let chainID):
            path = "/bc/\(chainID.value)"
        case .xChainVM(let vm): path = "/vm/\(vm)"
        case .pChain(let chainID):
            path = "/\(chainID.value)"
        case .cChain(let chainID):
            path = "/bc/\(chainID.value)/avax"
        case .cChainVM(let chainID):
            path = "/bc/\(chainID.value)/rpc"
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
        queue: DispatchQueue = .main,
        session: URLSession = .shared,
        headers: [String: String] = [:],
        encoder: ContentEncoder = JSONEncoder.rpc,
        decoder: ContentDecoder = JSONDecoder.rpc
    ) {
        self.url = url
        self.queue = queue
        self.session = session
        self.headers = headers
        self.encoder = encoder
        self.decoder = decoder
    }
    
    private func getURL(for api: ApiConnectionType) -> URL {
        URL(string: api.path, relativeTo: url)!
    }
    
    private func getURL(subscribable api: ApiConnectionType) -> URL? {
        let path: String
        switch api {
        case .cChainVM(let chainID):
            path = "/ext/bc/\(chainID.value)/ws"
        default:
            return nil
        }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.scheme = "wss"
        return URL(string: path, relativeTo: components.url)!
    }
    
    public func singleShot(api: ApiConnectionType) -> SingleShotConnection {
        HttpConnection(url: getURL(for: api), queue: queue, headers: [:], session: session)
    }
    
    public func rpc(api: ApiConnectionType) -> Client {
        JsonRpc(.http(url: getURL(for: api), session: session, headers: headers),
                queue: queue,
                encoder: encoder,
                decoder: decoder)
    }
    
    public func subscribableRPC(api: ApiConnectionType) -> Subscribable? {
        guard let url = getURL(subscribable: api) else {
            return nil
        }
        return JsonRpc(.ws(url: url), queue: queue, encoder: encoder, decoder: decoder)
    }
}
