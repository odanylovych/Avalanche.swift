//
//  EncoderDecoderProvider.swift
//  
//
//  Created by Ostap Danylovych on 18.12.2021.
//

import Foundation

public protocol AvalancheEncoderDecoderProvider {
    func encoder() -> AvalancheEncoder
    func decoder(context: AvalancheDecoderContext, data: Data) -> AvalancheDecoder
    func dataCoder() -> DataCoder
}

public struct DefaultAvalancheEncoderDecoderProvider: AvalancheEncoderDecoderProvider {
    
    public init() {}
    
    public func encoder() -> AvalancheEncoder {
        DefaultAvalancheEncoder()
    }
    
    public func decoder(context: AvalancheDecoderContext, data: Data) -> AvalancheDecoder {
        DefaultAvalancheDecoder(context: context, data: data)
    }
    
    public func dataCoder() -> DataCoder {
        HexNCDataCoder()
    }
}
