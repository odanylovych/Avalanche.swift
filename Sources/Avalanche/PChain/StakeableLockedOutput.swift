//
//  StakeableLockedOutput.swift
//  
//
//  Created by Ostap Danylovych on 01.09.2021.
//

import Foundation

public struct StakeableLockedOutput: Equatable {
    public static let typeID: PChainTypeID = .stakeableLockedOutput
    
    public let locktime: Date
    public let transferableOutput: TransferableOutput
    
    public init(locktime: Date, transferableOutput: TransferableOutput) {
        self.locktime = locktime
        self.transferableOutput = transferableOutput
    }
}

extension StakeableLockedOutput: AvalancheCodable {
    public init(from decoder: AvalancheDecoder) throws {
        let typeID: PChainTypeID = try decoder.decode()
        guard typeID == Self.typeID else {
            throw AvalancheDecoderError.dataCorrupted(
                typeID,
                AvalancheDecoderError.Context(path: decoder.path)
            )
        }
        self.init(
            locktime: try decoder.decode(),
            transferableOutput: try decoder.decode()
        )
    }
    
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.typeID, name: "typeID")
            .encode(locktime, name: "locktime")
            .encode(transferableOutput, name: "transferableOutput")
    }
}
