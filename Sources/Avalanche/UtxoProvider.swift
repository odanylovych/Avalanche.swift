//
//  UtxoProvider.swift
//  
//
//  Created by Yehor Popovych on 01.09.2021.
//

import Foundation

public protocol AvalancheUtxoProviderIterator {
    func next(
        limit: UInt32?,
        result: @escaping ApiCallback<(utxos: [UTXO],
                                       iterator: AvalancheUtxoProviderIterator?)>)
}

public protocol AvalancheUtxoProvider: AnyObject {
    func utxos<A: AvalancheVMApi>(api: A,
                                  ids: [(txID: TransactionID, index: UInt32)],
                                  result: @escaping ApiCallback<[UTXO]>)
    
    func utxos<A: AvalancheVMApi>(api: A, addresses: [Address]) -> AvalancheUtxoProviderIterator
}

public class AvalancheDefaultUtxoProvider: AvalancheUtxoProvider {
    private struct Iterator<A: AvalancheVMApi>: AvalancheUtxoProviderIterator {
        let api: A
        let addresses: [Address]
        let index: UTXOIndex?
        
        init(api: A, addresses: [Address], index: UTXOIndex?) {
            self.api = api
            self.addresses = addresses
            self.index = index
        }
        
        func next(
            limit: UInt32? = nil,
            result: @escaping ApiCallback<(utxos: [UTXO],
                                           iterator: AvalancheUtxoProviderIterator?)>)
        {
            api.getUTXOs(
                addresses: addresses,
                limit: limit,
                startIndex: index,
                sourceChain: api.info.blockchainID,
                encoding: AvalancheEncoding.cb58
            ) { res in
                result(res.map { (
                    utxos: $0.utxos,
                    iterator: Self(api: api, addresses: addresses, index: $0.endIndex)
                ) })
            }
        }
    }
    
    public init() {}
    
    private func allUtxos(
        limit: UInt32,
        iterator: AvalancheUtxoProviderIterator,
        all: [UTXO],
        result: @escaping ApiCallback<(utxos: [UTXO], last: Bool)>
    ) {
        iterator.next(limit: limit) { res in
            result(res.map { utxos, iterator in
                var all = all
                all += utxos
                if let iterator = iterator {
                    self.allUtxos(limit: limit, iterator: iterator, all: all, result: result)
                    return (utxos: all, last: false)
                }
                return (utxos: all, last: true)
            })
        }
    }
    
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
    
    public func utxos<A: AvalancheVMApi>(api: A, addresses: [Address]) -> AvalancheUtxoProviderIterator
    {
        return Iterator(api: api, addresses: addresses, index: nil)
    }
}
