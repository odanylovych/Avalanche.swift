//
//  Settings.swift
//  
//
//  Created by Daniel Leping on 17/12/2020.
//

import Foundation
import JsonRPC

public struct AvalancheSettings {
    public let queue: DispatchQueue
    public let addressManagerProvider: AddressManagerProvider
    public let utxoProvider: AvalancheUtxoProvider
    public let encoderDecoderProvider: AvalancheEncoderDecoderProvider
    
    public init(queue: DispatchQueue = .main,
                addressManagerProvider: AddressManagerProvider = DefaultAddressManagerProvider(),
                utxoProvider: AvalancheUtxoProvider = AvalancheDefaultUtxoProvider(),
                encoderDecoderProvider: AvalancheEncoderDecoderProvider = DefaultAvalancheEncoderDecoderProvider()) {
        self.queue = queue
        self.addressManagerProvider = addressManagerProvider
        self.utxoProvider = utxoProvider
        self.encoderDecoderProvider = encoderDecoderProvider
    }
}
