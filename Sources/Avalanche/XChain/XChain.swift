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
#endif

public class AvalancheXChainApiInfo: AvalancheBaseApiInfo {
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
    
    private let service: Client
    private let vmService: Client
    

    public required init(avalanche: AvalancheCore, networkID: NetworkID, hrp: String, info: Info) {
        self.keychain = avalanche.addressManager
        let settings = avalanche.settings
        
        self.service = JsonRpc(.http(url: avalanche.url(path: info.apiPath), session: settings.session, headers: settings.headers), queue: settings.queue, encoder: settings.encoder, decoder: settings.decoder)
        self.vmService = JsonRpc(.http(url: avalanche.url(path: info.vmApiPath), session: settings.session, headers: settings.headers), queue: settings.queue, encoder: settings.encoder, decoder: settings.decoder)
        
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
