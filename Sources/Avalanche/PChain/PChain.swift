//
//  PChain.swift
//  
//
//  Created by Yehor Popovych on 10/4/20.
//

import Foundation
import BigInt
#if !COCOAPODS
import RPC
#endif


public class AvalanchePChainApiInfo: AvalancheBaseApiInfo {
    public let txFee: BigUInt
    public let creationTxFee: BigUInt
    public let minConsumption: Double
    public let maxConsumption: Double
    public let maxStakingDuration: BigUInt
    public let maxSupply: BigUInt
    public let minStake: BigUInt
    public let minStakeDuration: UInt
    public let maxStakeDuration: UInt
    public let minDelegationStake: BigUInt
    public let minDelegationFee: BigUInt
    
    public init(
        minConsumption: Double, maxConsumption: Double, maxStakingDuration: BigUInt,
        maxSupply: BigUInt, minStake: BigUInt, minStakeDuration: UInt,
        maxStakeDuration: UInt, minDelegationStake: BigUInt, minDelegationFee: BigUInt,
        txFee: BigUInt, creationTxFee: BigUInt, blockchainID: BlockchainID,
        alias: String? = nil, vm: String = "platformvm"
    ) {
        self.minConsumption = minConsumption; self.maxConsumption = maxConsumption
        self.maxStakingDuration = maxStakingDuration; self.maxSupply = maxSupply
        self.minStake = minStake; self.minStakeDuration = minStakeDuration
        self.maxStakeDuration = maxStakeDuration; self.minDelegationStake = minDelegationStake
        self.minDelegationFee = minDelegationFee; self.txFee = txFee; self.creationTxFee = creationTxFee
        super.init(blockchainID: blockchainID, alias: alias, vm: vm)
    }
    
    override public var apiPath: String {
        return "/ext/\(alias ?? blockchainID.cb58())"
    }
}

public struct AvalanchePChainApi: AvalancheApi {
    public typealias Info = AvalanchePChainApiInfo
    
    public let signer: AvalancheSignatureProvider?
    private let service: Client
    
    public init(avalanche: AvalancheCore, networkID: NetworkID, hrp: String, info: Info) {
        self.signer = avalanche.signer
        
        let settings = avalanche.settings
        let url = avalanche.url(path: info.apiPath)
        
        self.service = JsonRpc(.http(url: url, session: settings.session, headers: settings.headers), queue: settings.queue, encoder: settings.encoder, decoder: settings.decoder)
    }
    
    
}

extension AvalancheCore {
    public var PChain: AvalanchePChainApi {
        return try! self.getAPI()
    }
    
    public func PChain(networkID: NetworkID, hrp: String, info: AvalanchePChainApi.Info) -> AvalanchePChainApi {
        return self.createAPI(networkID: networkID, hrp: hrp, info: info)
    }
}
