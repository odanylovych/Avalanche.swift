//
//  Web3SubscriptionNetworkProvider.swift
//  
//
//  Created by Ostap Danylovych on 20.01.2022.
//

import Foundation
#if !COCOAPODS
import web3swift
import RPC
import Serializable
#endif

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
    case eventParseError(Error)
}

public class Web3SubscriptionNetworkProvider: Web3NetworkProvider, Web3SubscriptionProvider, ServerDelegate {
    private let internalQueue: DispatchQueue
    private var service: Client & Delegator
    private var subscriptions = [String: (Parsable) -> Void]()
    
    public init(network: Networks?, url: URL, service: Client & Delegator) {
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
                                    .mapError { Web3SubscriptionError.eventParseError($0) })
                    }
                }
            }
        }
        return subscription
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
