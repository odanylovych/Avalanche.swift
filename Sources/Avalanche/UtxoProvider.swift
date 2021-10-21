//
//  UtxoProvider.swift
//  
//
//  Created by Yehor Popovych on 01.09.2021.
//

import Foundation

public protocol AvalancheUtxoProviderIterator {
    func next(
        limit: UInt32,
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
    
    func utxos<A: AvalancheVMApi>(api: A,
                                  limit: UInt32,
                                  addresses: [A.Keychain.Acct.Addr],
                                  result: @escaping ApiCallback<[UTXO]>)
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
            limit: UInt32,
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
                    iterator: $0.fetched < limit ? nil : Self(api: api, addresses: addresses, index: $0.endIndex)
                ) })
            }
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
        api: A,
        limit: UInt32,
        addresses: [A.Keychain.Acct.Addr],
        result: @escaping ApiCallback<[UTXO]>
    ) {
        let iterator = utxos(api: api, addresses: addresses, forceUpdate: true)
        allUtxos(limit: limit, iterator: iterator, all: []) { res in
            do {
                let res = try res.get()
                if res.last {
                    result(.success(res.utxos))
                }
            } catch {
                result(.failure(error as! AvalancheApiError))
            }
        }
    }
    
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
    
    public func utxos<A: AvalancheVMApi>(
        api: A,
        addresses: [A.Keychain.Acct.Addr],
        forceUpdate: Bool
    ) -> AvalancheUtxoProviderIterator
    {
        return Iterator(api: api, addresses: addresses, index: nil)
    }
}
