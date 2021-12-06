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
        fatalError("Not implemented")
    }
    
    public func rpc(api: ApiConnection) -> Client {
        let apiURL: URL
        switch api {
        case .xChain(let path):
            apiURL = URL(string: path, relativeTo: url)!
        case .xChainVm(let path):
            apiURL = URL(string: path, relativeTo: url)!
        }
        return JsonRpc(
            .http(url: apiURL, session: session, headers: headers),
            queue: queue,
            encoder: encoder,
            decoder: decoder
        )
    }
    
    public func subscribableRPC(api: ApiConnection) -> PersistentConnection {
        fatalError("Not implemented")
    }
}
