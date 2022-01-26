//
//  EthAddress.swift
//  
//
//  Created by Ostap Danylovych on 24.01.2022.
//

import Foundation
#if !COCOAPODS
import web3swift
#endif

extension EthereumAddress {
    public init(from address: EthAddress) {
        self.init(address.rawAddress)!
    }
}

extension EthAddress {
    public init(from address: EthereumAddress) {
        try! self.init(pubKey: address.addressData)
    }
}
