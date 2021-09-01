//
//  XChain.swift
//  
//
//  Created by Yehor Popovych on 10/14/20.
//

import Foundation
import BigInt
//import RPC

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
    
    //FIX: private let network: AvalancheRpcConnection
    //FIX: private let vmNetwork: AvalancheRpcConnection
    public let signer: AvalancheSignatureProvider?
    
    public required init(avalanche: AvalancheCore, networkID: NetworkID, hrp: String, info: Info) {
        //FIX: self.network = avalanche.connections.httpRpcConnection(for: info.apiPath)
        //FIX: self.vmNetwork = avalanche.connections.httpRpcConnection(for: info.vmApiPath)
        self.signer = avalanche.signer
    }
}

extension AvalancheCore {
    public var XChain: AvalancheXChainApi {
        return try! self.getAPI()
    }
    
    public func XChain(networkID: NetworkID, hrp: String, info: AvalancheXChainApi.Info) -> AvalancheXChainApi {
        return self.createAPI(networkID: networkID, hrp: hrp, info: info)
    }
}
