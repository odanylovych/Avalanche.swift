//
//  UtxoProvider.swift
//  
//
//  Created by Yehor Popovych on 01.09.2021.
//

import Foundation

public enum AvalancheUtxoProviderError: Error {
    case noOutput(index: UInt32, transactionID: String)
}

public protocol AvalancheUtxoProviderIterator {
    func next(
        limit: UInt32?,
        sourceChain: BlockchainID?,
        result: @escaping ApiCallback<(utxos: [UTXO],
                                       iterator: AvalancheUtxoProviderIterator?)>)
}

extension AvalancheUtxoProviderIterator {
    func next(
        limit: UInt32? = nil,
        sourceChain: BlockchainID? = nil,
        result: @escaping ApiCallback<(utxos: [UTXO],
                                       iterator: AvalancheUtxoProviderIterator?)>) {
        next(limit: limit, sourceChain: sourceChain, result: result)
    }
}

public protocol AvalancheUtxoProvider: AnyObject {
    func utxos<A: AvalancheVMApi>(api: A,
                                  ids: [(txID: TransactionID, index: UInt32)],
                                  result: @escaping ApiCallback<[UTXO]>)
    
    func utxos<A: AvalancheVMApi>(api: A, addresses: [Address]) -> AvalancheUtxoProviderIterator
}

public class AvalancheDefaultUtxoProvider: AvalancheUtxoProvider {
    private struct Iterator<A: AvalancheVMApi>: AvalancheUtxoProviderIterator {
        let defaultLimit: UInt32 = 1024
        
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
            sourceChain: BlockchainID? = nil,
            result: @escaping ApiCallback<(utxos: [UTXO], iterator: AvalancheUtxoProviderIterator?)>
        ) {
            api.getUTXOs(
                addresses: addresses,
                limit: limit,
                startIndex: index,
                sourceChain: sourceChain,
                encoding: AvalancheEncoding.cb58
            ) { res in
                result(res.map {
                    let isMore = $0.fetched == limit ?? defaultLimit || $0.fetched == defaultLimit
                    return (
                        utxos: $0.utxos,
                        iterator: isMore ? Self(api: api, addresses: addresses, index: $0.endIndex) : nil
                    )
                })
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
        txIds.asyncMap { element, mapped in
            let (id, indexes) = element
            api.getTransaction(id: id) { res in
                switch res {
                case .success(let transaction):
                    let outputs = transaction.unsignedTransaction.allOutputs
                    var utxos = [UTXO]()
                    for index in indexes {
                        guard outputs.count > index else {
                            mapped(.failure(.custom(cause: AvalancheUtxoProviderError.noOutput(
                                index: index, transactionID: id.cb58()
                            ))))
                            return
                        }
                        let output = outputs[Int(index)]
                        utxos.append(UTXO(
                            transactionID: id,
                            utxoIndex: index,
                            assetID: output.assetID,
                            output: output.output
                        ))
                    }
                    mapped(.success(utxos))
                case .failure(let error):
                    mapped(.failure(error))
                }
            }
        }.exec { (res: Result<[[UTXO]], AvalancheApiError>) in
            result(res.map { utxos in utxos.flatMap { $0 } })
        }
    }
    
    public func utxos<A: AvalancheVMApi>(api: A, addresses: [Address]) -> AvalancheUtxoProviderIterator
    {
        return Iterator(api: api, addresses: addresses, index: nil)
    }
}
