//
//  InitialState.swift
//  
//
//  Created by Ostap Danylovych on 28.08.2021.
//

import Foundation

public enum FeatureExtensionID: UInt32, CaseIterable {
    case secp256K1 = 0x00000000
    case nft = 0x00000001
}

extension FeatureExtensionID: AvalancheCodable {
    public init(from decoder: AvalancheDecoder) throws {
        let rawValue: UInt32 = try decoder.decode()
        guard let featureExtensionID = Self(rawValue: rawValue) else {
            throw AvalancheDecoderError.dataCorrupted(
                rawValue,
                AvalancheDecoderError.Context(path: decoder.path, description: "Cannot find such FeatureExtensionID")
            )
        }
        self = featureExtensionID
    }
    
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(rawValue)
    }
}

public struct InitialState: Equatable {
    public let featureExtensionID: FeatureExtensionID
    public let outputs: [Output]

    public init(featureExtensionID: FeatureExtensionID, outputs: [Output]) {
        self.featureExtensionID = featureExtensionID
        self.outputs = outputs
    }
}

extension InitialState: AvalancheCodable {
    public init(from decoder: AvalancheDecoder) throws {
        self.init(
            featureExtensionID: try decoder.decode(name: "featureExtensionID"),
            outputs: try decoder.dynamic(name: "outputs")
        )
    }
    
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(featureExtensionID, name: "featureExtensionID")
            .encode(outputs, name: "outputs")
    }
}
