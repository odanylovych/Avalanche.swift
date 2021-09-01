//
//  UtxoCache.swift
//  
//
//  Created by Yehor Popovych on 01.09.2021.
//

import Foundation

public protocol AvalancheUtxoCache: AnyObject {
    func utxo(for addresses: Address,
              result: @escaping (Result<[Any], Error>) -> Void)
}
