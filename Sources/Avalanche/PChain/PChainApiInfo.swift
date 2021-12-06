//
//  PChainApiInfo.swift
//  
//
//  Created by Yehor Popovych on 01.09.2021.
//

import Foundation
import BigInt

public class AvalanchePChainApiInfo: AvalancheBaseVMApiInfo {
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
    
    override public var connection: ApiConnection {
        return .pChain(path: "/ext/\(chainId)")
    }
}
