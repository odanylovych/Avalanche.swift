//
//  Algos.swift
//  
//
//  Created by Yehor Popovych on 26.08.2021.
//

import Foundation

public enum Algos {
    public static let Bech: BechAlgos = BechAlgos()
    public static let Avalanche: AvalancheAlgos = AvalancheAlgos()
    public static let Secp256k1: Secp256k1Algos = Secp256k1Algos()
    public static let Ethereum: EthereumAlgos = EthereumAlgos()
}
