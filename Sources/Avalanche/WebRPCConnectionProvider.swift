//
//  WebRPCConnectionProvider.swift
//  
//
//  Created by Ostap Danylovych on 06.12.2021.
//

import Foundation
import RPC

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
    
    public func singleShot(api: ApiConnection) -> SingleShotConnection {
        let apiPath: String
        switch api {
        case .admin(let path): apiPath = path
        case .auth(let path): apiPath = path
        case .health(let path): apiPath = path
        case .info(let path): apiPath = path
        case .ipc(let path): apiPath = path
        case .keystore(let path): apiPath = path
        case .metrics(let path): apiPath = path
        case .xChain(let path): apiPath = path
        case .xChainVM(let path): apiPath = path
        case .pChain(let path): apiPath = path
        case .cChain(let path): apiPath = path
        case .cChainWS(let path): apiPath = path
        }
        let url = URL(string: apiPath, relativeTo: url)!
        return HttpConnection(url: url, queue: queue, headers: [:], session: session)
    }
    
    public func rpc(api: ApiConnection) -> Client {
        let apiPath: String
        switch api {
        case .admin(let path): apiPath = path
        case .auth(let path): apiPath = path
        case .health(let path): apiPath = path
        case .info(let path): apiPath = path
        case .ipc(let path): apiPath = path
        case .keystore(let path): apiPath = path
        case .metrics(let path): apiPath = path
        case .xChain(let path): apiPath = path
        case .xChainVM(let path): apiPath = path
        case .pChain(let path): apiPath = path
        case .cChain(let path): apiPath = path
        case .cChainWS(let path): apiPath = path
        }
        let url = URL(string: apiPath, relativeTo: url)!
        return JsonRpc(
            .http(url: url, session: session, headers: headers),
            queue: queue,
            encoder: encoder,
            decoder: decoder
        )
    }
    
    public func subscribableRPC(api: ApiConnection) -> PersistentConnection {
        fatalError("Not implemented")
    }
}
