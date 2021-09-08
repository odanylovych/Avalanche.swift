//
//  PChain+Transactions.swift
//  
//
//  Created by Yehor Popovych on 02.09.2021.
//

import Foundation

extension AvalanchePChainApi {
    public func txAddDelegator(
        nodeID: NodeID, startTime: Date, endTime: Date,
        stakeAmount: UInt64, reward: Address,
        from: Array<Address>? = nil, change: Address? = nil,
        account: Account,
        _ cb: @escaping ApiCallback<(txID: TransactionID, change: Address)>)
    {
        guard let keychain = self.keychain else {
            self.queue.async { cb(.failure(.nilAddressManager)) }
            return
        }
//        let extFrom: Array<ExtendedAddress>
//        if let from = from {
//            extFrom = keychain.extended(for: from)
//        } else {
//            
//        }
        
        
    }
}
