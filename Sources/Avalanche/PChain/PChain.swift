//
//  PChain.swift
//  
//
//  Created by Yehor Popovych on 10/4/20.
//

import Foundation
import BigInt
import Serializable
#if !COCOAPODS
import RPC
#endif

public struct AvalanchePChainApi: AvalancheVMApi {
    public typealias Info = AvalanchePChainApiInfo
    public typealias Keychain = AvalanchePChainApiAddressManager
    
    private let service: Client
    private let addressManager: AvalancheAddressManager?
    private let queue: DispatchQueue
    
    public let info: Info
    public let hrp: String
    
    public var keychain: AvalanchePChainApiAddressManager? {
        addressManager.map {
            AvalanchePChainApiAddressManager(manager: $0, api: self)
        }
    }
    
    public init(avalanche: AvalancheCore,
                networkID: NetworkID,
                hrp: String,
                info: Info)
    {
        let settings = avalanche.settings
        
        self.addressManager = avalanche.addressManager
        self.info = info
        self.hrp = hrp
        self.queue = settings.queue
        
        let url = avalanche.url(path: info.apiPath)
        
        self.service = JsonRpc(.http(url: url, session: settings.session, headers: settings.headers), queue: settings.queue, encoder: settings.encoder, decoder: settings.decoder)
    }
    
    public struct AddDelegatorParams: Encodable {
        public let nodeID: String
        public let startTime: Int64
        public let endTime: Int64
        public let stakeAmount: UInt64
        public let rewardAddress: String
        public let from: Array<String>?
        public let changeAddr: String?
        public let username: String
        public let password: String
    }
    
    public struct AddDelegatorResponse: Decodable {
        public let txID: String
        public let changeAddr: String
    }
    
    public func addDelegator(
        nodeID: NodeID, startTime: Date, endTime: Date, stakeAmount: UInt64,
        reward: Address, from: Array<Address>? = nil, change: Address? = nil,
        credentials: VmApiCredentials,
        _ cb: @escaping ApiCallback<(txID: TransactionID, change: Address)>
    ) {
        switch credentials {
        case .password(username: let user, password: let pass):
            let params = AddDelegatorParams(
                nodeID: nodeID.cb58(),
                startTime: Int64(startTime.timeIntervalSince1970),
                endTime: Int64(endTime.timeIntervalSince1970),
                stakeAmount: stakeAmount, rewardAddress: reward.bech,
                from: from.map { $0.map { $0.bech } },
                changeAddr: change?.bech, username: user, password: pass)
            service.call(method: "platform.addDelegator",
                         params: params,
                         AddDelegatorResponse.self,
                         SerializableValue.self) { res in
                cb(res
                    .mapError(AvalancheApiError.init)
                    .map { (TransactionID(cb58: $0.txID)!, try! Address(bech: $0.changeAddr)) })
            }
        case .account(let account):
            // TODO: Build and execute TX.
            // Extended Addresses can be obtained from self.keychain
            fatalError("Not implemented")
        }
    }
    
    public struct CreateAddressParams: Encodable {
        public let username: String
        public let password: String
    }
    
    public struct CreateAddressResponse: Decodable {
        public let address: String
    }
    
    public func createAddress(
        credentials: VmApiCredentials,
        _ cb: @escaping ApiCallback<Address>) {
        switch credentials {
        case .password(username: let user, password: let pass):
            service.call(method: "platform.createAddress",
                         params: CreateAddressParams(username: user, password: pass),
                         CreateAddressResponse.self,
                         SerializableValue.self) { res in
                cb(res.mapError(AvalancheApiError.init).map { try! Address(bech: $0.address) }) // TODO: error handling
            }
        case .account(let account):
            self.queue.async {
                guard let kc = keychain else {
                    cb(.failure(.emptyAddressManager))
                    return
                }
                cb(.success(kc.newAddress(for: account)))
            }
        }
    }
    
    public struct GetUTXOParams: Encodable {
        public struct Index {
            public let address: String
            public let utxo: String
        }
        
        public let addresses: [String]
        public let limit: UInt32?
        public let sourceChain: String
        public let encoding: String
    }
    
    public struct GetUTXOResponse {
        public let address: String
    }
    
    public func getUTXOs() {
        
    }
}

extension AvalancheCore {
    public var pChain: AvalanchePChainApi {
        return try! self.getAPI()
    }
    
    public func pChain(networkID: NetworkID, hrp: String, info: AvalanchePChainApi.Info) -> AvalanchePChainApi {
        return self.createAPI(networkID: networkID, hrp: hrp, info: info)
    }
}
