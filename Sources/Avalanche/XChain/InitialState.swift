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

extension FeatureExtensionID: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(rawValue)
    }
}

public struct InitialState {
    public let featureExtensionID: FeatureExtensionID
    public let outputs: [Output]

    public init(featureExtensionID: FeatureExtensionID, outputs: [Output]) {
        self.featureExtensionID = featureExtensionID
        self.outputs = outputs
    }
}

extension InitialState: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(featureExtensionID, name: "featureExtensionID")
            .encode(outputs, name: "outputs")
    }
}
