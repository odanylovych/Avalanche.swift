//
//  XChain.swift
//  
//
//  Created by Yehor Popovych on 10/14/20.
//

import Foundation
import BigInt
#if !COCOAPODS
import RPC
import Serializable
#endif

public class AvalancheXChainApiInfo: AvalancheBaseVMApiInfo {
    public let txFee: BigUInt
    public let creationTxFee: BigUInt
    
    public init(
        txFee: BigUInt, creationTxFee: BigUInt, blockchainID: BlockchainID,
        alias: String? = nil, vm: String = "avm"
    ) {
        self.txFee = txFee
        self.creationTxFee = creationTxFee
        super.init(blockchainID: blockchainID, alias: alias, vm: vm)
    }
    
    public var vmApiPath: String {
        return "/ext/vm/\(vm)"
    }
}

public class AvalancheXChainApi: AvalancheApi {
    public typealias Info = AvalancheXChainApiInfo
    
    public let keychain: AvalancheAddressManager?
    
    public let networkID: NetworkID
    public let hrp: String
    public let info: Info
    
    private let service: Client
    private let vmService: Client
    

    public required init(avalanche: AvalancheCore, networkID: NetworkID, hrp: String, info: Info) {
        self.networkID = networkID
        self.hrp = hrp
        self.info = info
        
        self.keychain = avalanche.addressManager
        let settings = avalanche.settings
        
        self.service = JsonRpc(.http(url: avalanche.url(path: info.apiPath), session: settings.session, headers: settings.headers), queue: settings.queue, encoder: settings.encoder, decoder: settings.decoder)
        self.vmService = JsonRpc(.http(url: avalanche.url(path: info.vmApiPath), session: settings.session, headers: settings.headers), queue: settings.queue, encoder: settings.encoder, decoder: settings.decoder)
    }
    
    public struct InitialHolder: Encodable {
        public let address: String
        public let amount: UInt64
    }
    
    public struct CreateFixedCapAssetParams: Encodable {
        public let name: String
        public let symbol: String
        public let denomination: UInt32?
        public let initialHolders: [InitialHolder]
        public let from: [String]
        public let changeAddr: String?
        public let username: String
        public let password: String
    }
    
    public struct CreateFixedCapAssetResponse: Decodable {
        public let assetID: String
        public let changeAddr: String
    }
    
    public func createFixedCapAsset(
        name: String,
        symbol: String,
        denomination: UInt32? = nil,
        initialHolders: [(address: Address, amount: UInt64)],
        from: [String],
        change: Address? = nil,
        credentials: AvalancheVmApiCredentials,
        _ cb: @escaping ApiCallback<(assetID: AssetID, change: Address)>
    ) {
        switch credentials {
        case .password(let username, let password):
            let params = CreateFixedCapAssetParams(
                name: name,
                symbol: symbol,
                denomination: denomination,
                initialHolders: initialHolders.map {
                    InitialHolder(address: $0.address.bech, amount: $0.amount)
                },
                from: from,
                changeAddr: change?.bech,
                username: username,
                password: password
            )
            service.call(
                method: "avm.createFixedCapAsset",
                params: params,
                CreateFixedCapAssetResponse.self,
                SerializableValue.self
            ) { res in
                cb(res
                    .mapError(AvalancheApiError.init)
                    .map { (AssetID(cb58: $0.assetID)!, try! Address(bech: $0.changeAddr)) })
            }
        case .account:
            fatalError("Not implemented")
        }
    }
}

extension AvalancheCore {
    public var xChain: AvalancheXChainApi {
        return try! self.getAPI()
    }
    
    public func xChain(networkID: NetworkID, hrp: String, info: AvalancheXChainApi.Info) -> AvalancheXChainApi {
        return self.createAPI(networkID: networkID, hrp: hrp, info: info)
    }
}
