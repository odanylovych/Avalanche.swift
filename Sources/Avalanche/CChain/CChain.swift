//
//  CChain.swift
//  
//
//  Created by Yehor Popovych on 10/14/20.
//

import Foundation
import BigInt
//import RPC

public class AvalancheCChainApiInfo: AvalancheBaseApiInfo {
    public let gasPrice: BigUInt
    public let chainId: UInt32
    
    public init(
        gasPrice: BigUInt, chainId: UInt32, bId: String,
        alias: String? = nil, vm: String = "evm"
    ) {
        self.gasPrice = gasPrice
        self.chainId = chainId
        super.init(bId: bId, alias: alias, vm: vm)
    }
    
    override public var apiPath: String {
        return super.apiPath + "/rpc"
    }
    
    public var wsApiPath: String {
        return super.apiPath + "/ws"
    }
}

public class AvalancheCChainApi: AvalancheApi {
    public typealias Info = AvalancheCChainApiInfo
    
    private struct SubscriptionId: Decodable {
        let subscription: String
    }
    
    private var subscriptions: Dictionary<String, (Data) -> Void>
    private var subscriptionId: UInt?
    //FIX: public let network: AvalancheSubscribableRpcConnection
    public let keychain: Keychain
    
    public required init(avalanche: AvalancheCore, network: AvalancheNetwork, hrp: String, info: Info) {
        //FIX: self.network = avalanche.connections.wsRpcConnection(for: info.wsApiPath)
        self.keychain = avalanche.keychain
        self.subscriptions = [:]
        self.subscriptionId = nil
    }
    
    private func processMessage(data: Data) {
        do {
            /*//FIX: let (_, id) = try network.parseInfo(from: data, SubscriptionId.self)
            guard let handler = subscriptions[id.subscription] else {
                return
            }
            handler(data)*/
        } catch {}
    }
    
    private func subscribeIfNeeded() {
        guard subscriptionId == nil else { return }
        /*//FIX: self.subscriptionId = network.subscribe { [weak self] data, _ in
            self?.processMessage(data: data)
        }*/
    }
    
    private func unsubscribeIfNeeded() {
        guard let subId = subscriptionId, subscriptions.count == 0 else { return }
        subscriptionId = nil
        //FIX: network.unsubscribe(id: subId)
    }
    
    // Subscription Example. Should be updated to proper types
    /*//FIX: public func eth_subscribe<T: CChainSubscriptionType>(
        _ params: T,
        result: @escaping AvalancheRpcConnectionCallback<T, CChainSubscription<T.Event>, CChainError>
    ) {
        self.subscribeIfNeeded()
        /*//FIX: network.call(method: "eth_subscribe", params: params, String.self) { res in
            result(res.map {
                let sub = CChainSubscription<T.Event>(id: $0, api: self)
                self.subscriptions[$0] = sub.handler
                return sub
            })
        }*/
    }*/

    /*//FIX: public func eth_unsubscribe<S: CChainSubscription<M>, M: Decodable>(
        _ subcription: S, result: @escaping AvalancheRpcConnectionCallback<String, Bool, CChainError>
    ) {
        // TODO: fix multithreading
        self.subscriptions.removeValue(forKey: subcription.id)
        self.unsubscribeIfNeeded()
        //FIX: network.call(method: "eth_unsubscribe", params: subcription.id, Bool.self, response: result)
    }*/
}

extension AvalancheCore {
    public var CChain: AvalancheCChainApi {
        return try! self.getAPI()
    }
    
    public func CChain(network: AvalancheNetwork, hrp: String, info: AvalancheCChainApi.Info) -> AvalancheCChainApi {
        return self.createAPI(network: network, hrp: hrp, info: info)
    }
}
