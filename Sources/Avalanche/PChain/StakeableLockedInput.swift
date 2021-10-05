//
//  StakeableLockedInput.swift
//  
//
//  Created by Ostap Danylovych on 01.09.2021.
//

import Foundation

public struct StakeableLockedInput: Equatable {
    public static let typeID: PChainTypeID = .stakeableLockedInput
    
    public let locktime: Date
    public let transferableInput: TransferableInput
    
    public init(locktime: Date, transferableInput: TransferableInput) {
        self.locktime = locktime
        self.transferableInput = transferableInput
    }
}

extension StakeableLockedInput: AvalancheCodable {
    public init(from decoder: AvalancheDecoder) throws {
        let typeID: PChainTypeID = try decoder.decode(name: "typeID")
        guard typeID == Self.typeID else {
            throw AvalancheDecoderError.dataCorrupted(
                typeID,
                AvalancheDecoderError.Context(path: decoder.path)
            )
        }
        self.init(
            locktime: try decoder.decode(name: "locktime"),
            transferableInput: try decoder.decode(name: "transferableInput")
        )
    }
    
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.typeID, name: "typeID")
            .encode(locktime, name: "locktime")
            .encode(transferableInput, name: "transferableInput")
    }
}
