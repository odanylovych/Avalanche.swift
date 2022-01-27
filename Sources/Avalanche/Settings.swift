//
//  Settings.swift
//  
//
//  Created by Daniel Leping on 17/12/2020.
//

import Foundation
#if !COCOAPODS
import RPC
#endif
#if os(Linux)
import FoundationNetworking
#endif

public struct AvalancheSettings {
    public let queue: DispatchQueue
    public let networkInfoProvider: AvalancheNetworkInfoProvider
    public let addressManagerProvider: AddressManagerProvider
    public let utxoProvider: AvalancheUtxoProvider
    public let encoderDecoderProvider: AvalancheEncoderDecoderProvider
    
    public init(queue: DispatchQueue = .main,
                networkInfoProvider: AvalancheNetworkInfoProvider = AvalancheDefaultNetworkInfoProvider.default,
                addressManagerProvider: AddressManagerProvider = DefaultAddressManagerProvider(),
                utxoProvider: AvalancheUtxoProvider = AvalancheDefaultUtxoProvider(),
                encoderDecoderProvider: AvalancheEncoderDecoderProvider = DefaultAvalancheEncoderDecoderProvider()) {
        self.queue = queue
        self.networkInfoProvider = networkInfoProvider
        self.addressManagerProvider = addressManagerProvider
        self.utxoProvider = utxoProvider
        self.encoderDecoderProvider = encoderDecoderProvider
    }
}
