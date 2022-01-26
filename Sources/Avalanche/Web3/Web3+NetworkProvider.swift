//
//  Web3+NetworkProvider.swift
//  
//
//  Created by Ostap Danylovych on 18.01.2022.
//

import Foundation
#if !COCOAPODS
import web3swift
import PromiseKit
import RPC
import Serializable
#endif

public class Web3NetworkProvider: Web3Provider {
    public var network: Networks?
    public var url: URL
    private let service: Client

    public init(network: Networks?, url: URL, service: Client) {
        self.network = network
        self.url = url
        self.service = service
    }

    public func sendAsync(_ request: JSONRPCrequest, queue: DispatchQueue) -> Promise<JSONRPCresponse> {
        guard let method = request.method else {
            return Promise(error: Web3Error.inputError(desc: "No method in request: \(request)"))
        }
        guard let params = request.params else {
            return Promise(error: Web3Error.inputError(desc: "No params in request: \(request)"))
        }
        return Promise { resolver in
            service.call(
                method: method.rawValue,
                params: params,
                JSONRPCresponse.Result.self,
                SerializableValue.self
            ) { res in
                switch res {
                case .success(let result):
                    queue.async {
                        resolver.fulfill(JSONRPCresponse(
                            id: Int(request.id),
                            jsonrpc: request.jsonrpc,
                            result: result,
                            error: nil
                        ))
                    }
                case .failure(let error):
                    queue.async {
                        switch error {
                        case .service(error: let error):
                            resolver.reject(error)
                        case .empty:
                            resolver.fulfill(JSONRPCresponse(
                                id: Int(request.id),
                                jsonrpc: request.jsonrpc,
                                result: JSONRPCresponse.Result(value: nil),
                                error: nil
                            ))
                        case .reply(method: _, params: _, error: let error):
                            resolver.fulfill(JSONRPCresponse(
                                id: Int(request.id),
                                jsonrpc: request.jsonrpc,
                                result: JSONRPCresponse.Result(value: nil),
                                error: JSONRPCresponse.ErrorMessage(code: error.code, message: error.message)
                            ))
                        case .custom(description: let description, cause: let cause):
                            resolver.reject(cause ?? Web3Error.nodeError(desc: description))
                        }
                    }
                }
            }
        }
    }

    public func sendAsync(_ requests: JSONRPCrequestBatch, queue: DispatchQueue) -> Promise<JSONRPCresponseBatch> {
        when(fulfilled: requests.requests.map { sendAsync($0, queue: queue) }).map { responses in
            JSONRPCresponseBatch(responses: responses)
        }
    }
}
