//
//  UtxoProvider.swift
//  
//
//  Created by Yehor Popovych on 01.09.2021.
//

import Foundation

public protocol AvalancheUtxoProviderIterator {
    func next(
        limit: Int,
        result: @escaping ApiCallback<(utxos: [UTXO],
                                       iterator: AvalancheUtxoProviderIterator?)>)
}

public protocol AvalancheUtxoProvider: AnyObject {
    func utxos<A: AvalancheVMApi>(api: A,
                                  ids: [(txID: TransactionID, index: UInt32)],
                                  result: @escaping ApiCallback<[UTXO]>)
    
    func utxos<A: AvalancheVMApi>(api: A,
                                  addresses: [A.Keychain.Acct.Addr],
                                  forceUpdate: Bool) -> AvalancheUtxoProviderIterator
}

public class AvalancheDefaultUtxoProvider: AvalancheUtxoProvider {
    private struct Iterator<A: AvalancheVMApi>: AvalancheUtxoProviderIterator {
        let api: A
        let addresses: [A.Keychain.Acct.Addr]
        let index: UTXOIndex?
        
        init(api: A, addresses: [A.Keychain.Acct.Addr], index: UTXOIndex?) {
            self.api = api
            self.addresses = addresses
            self.index = index
        }
        
        func next(
            limit: Int,
            result: @escaping ApiCallback<(utxos: [UTXO],
                                           iterator: AvalancheUtxoProviderIterator?)>)
        {
            //TODO: Implement. Call API, check does it have more. Call result with iterator
        }
    }
    
    public init() {}
    
    public func utxos<A: AvalancheVMApi>(api: A,
                                         ids: [(txID: TransactionID, index: UInt32)],
                                         result: @escaping ApiCallback<[UTXO]>) {
        let txIds: Dictionary<TransactionID, [UInt32]> = ids.reduce([:], { dict, id in
            var dict = dict
            dict[id.txID] = (dict[id.txID] ?? []) + [id.index]
            return dict
        })
        // TODO: Recursive call VMAPI method
    }
    
    public func utxos<A: AvalancheVMApi>(
        api: A, addresses: [A.Keychain.Acct.Addr],
        forceUpdate: Bool) -> AvalancheUtxoProviderIterator
    {
        return Iterator(api: api, addresses: addresses, index: nil)
    }
}
