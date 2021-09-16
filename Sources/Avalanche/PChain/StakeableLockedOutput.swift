//
//  StakeableLockedOutput.swift
//  
//
//  Created by Ostap Danylovych on 01.09.2021.
//

import Foundation

public struct StakeableLockedOutput {
    public static let typeID: TypeID = PChainTypeID.stakeableLockedOutput
    
    public let locktime: Date
    public let transferableOutput: TransferableOutput
    
    public init(locktime: Date, transferableOutput: TransferableOutput) {
        self.locktime = locktime
        self.transferableOutput = transferableOutput
    }
}

extension StakeableLockedOutput: AvalancheCodable {
    public init(from decoder: AvalancheDecoder) throws {
        self.init(
            locktime: try Date(from: decoder),
            transferableOutput: try TransferableOutput(from: decoder)
        )
    }
    
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.typeID, name: "typeID")
            .encode(locktime, name: "locktime")
            .encode(transferableOutput, name: "transferableOutput")
    }
}
