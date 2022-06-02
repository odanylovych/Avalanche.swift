//
//  Web3NetworkProvider.swift
//  
//
//  Created by Ostap Danylovych on 18.01.2022.
//

import Foundation
import web3swift
import PromiseKit
import JsonRPC
import Serializable

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

public class Web3Subscription: Subscription {
    public var id: String? = nil
    private let unsubscribeCallback: (Web3Subscription) -> Void
    
    public init(unsubscribeCallback: @escaping (Web3Subscription) -> Void) {
        self.unsubscribeCallback = unsubscribeCallback
    }
    
    public func unsubscribe() {
        unsubscribeCallback(self)
    }
}

public enum Web3SubscriptionError: Error {
    case parseEventError(CodecError)
}

public class Web3SubscriptionNetworkProvider: Web3NetworkProvider, Web3SubscriptionProvider, ServerDelegate, ErrorDelegate {
    private let internalQueue: DispatchQueue
    private var service: Subscribable
    private var subscriptions = [String: (Parsable) -> Void]()
    
    public init(network: Networks?, url: URL, service: Subscribable) {
        internalQueue = DispatchQueue(
            label: "subscription.network.provider.sync.queue",
            target: .global()
        )
        self.service = service
        super.init(network: network, url: url, service: service)
        self.service.delegate = self
    }
    
    public struct SubscribeParams: Encodable {
        public let params: [Any]
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()
            try params.forEach { param in
                if let param = param as? String {
                    try container.encode(param)
                } else if let param = param as? SubscribeOnLogsParams {
                    try container.encode(param)
                }
            }
        }
    }

    public struct SubscriptionID: Decodable {
        public let subscription: String
    }
    
    public struct SubscriptionEvent<R: Decodable>: Decodable {
        public let result: R
    }
    
    public func subscribe<R>(filter: SubscribeEventFilter,
                             queue: DispatchQueue,
                             listener: @escaping Web3SubscriptionListener<R>) -> Subscription {
        let subscription = Web3Subscription { subscription in
            guard let id = subscription.id else {
                return
            }
            self.service.call(method: JSONRPCmethod.unsubscribe.rawValue,
                              params: [id],
                              Bool.self,
                              SerializableValue.self) { res in
                queue.async {
                    guard let unsubscribed = try? res.get(), unsubscribed else {
                        return
                    }
                    self.internalQueue.sync {
                        _ = self.subscriptions.removeValue(forKey: id)
                    }
                }
            }
        }
        service.call(method: JSONRPCmethod.subscribe.rawValue,
                     params: SubscribeParams(params: filter.params),
                     String.self,
                     SerializableValue.self) { res in
            queue.async {
                guard let subscriptionID = try? res.get() else {
                    return
                }
                self.internalQueue.sync {
                    subscription.id = subscriptionID
                    self.subscriptions[subscriptionID] = { event in
                        listener(event.parse(to: SubscriptionEvent<R>.self)
                                    .map { $0!.result }
                                    .mapError(Web3SubscriptionError.parseEventError))
                    }
                }
            }
        }
        return subscription
    }
    
    public func error(_ error: ServiceError) {
        let format = { (name: String, data: Data) -> String in
            let text = ", \(name): "
            if let str = String(data: data, encoding: .utf8) {
                return text + str
            }
            return text + data.hex()
        }
        var errorMessage = String(describing: error)
        switch error {
        case .connection(let cause):
            switch cause {
            case .http(_, let message):
                if let message = message {
                    errorMessage += format("message", message)
                }
            default:
                break
            }
        case .unregisteredResponse(_, let body):
            errorMessage += format("body", body)
        default:
            break
        }
        print("WebSocket error: \(errorMessage)")
    }
    
    public func notification(method: String, params: Parsable) {
        guard method == "eth_subscription",
              let id = try? params.parse(to: SubscriptionID.self).get(),
              let subscription = subscriptions[id.subscription] else {
            return
        }
        subscription(params)
    }
}
