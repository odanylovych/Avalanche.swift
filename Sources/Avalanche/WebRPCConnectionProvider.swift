//
//  WebRPCConnectionProvider.swift
//  
//
//  Created by Ostap Danylovych on 06.12.2021.
//

import Foundation
import RPC

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
    
    public func singleShot(api: ApiConnectionType) -> SingleShotConnection {
        let url = URL(string: api.path, relativeTo: url)!
        return HttpConnection(url: url, queue: queue, headers: [:], session: session)
    }
    
    public func rpc(api: ApiConnectionType) -> Client {
        let url = URL(string: api.path, relativeTo: url)!
        return JsonRpc(
            .http(url: url, session: session, headers: headers),
            queue: queue,
            encoder: encoder,
            decoder: decoder
        )
    }
    
    public func subscribableRPC(api: ApiConnectionType) -> PersistentConnection? {
        switch api {
        case .cChainVM(let alias, let blockchainID):
            let _ = "/ext/bc/\(alias ?? blockchainID.cb58())/ws"
            fatalError("Not implemented")
        default: return nil
        }
    }
}
