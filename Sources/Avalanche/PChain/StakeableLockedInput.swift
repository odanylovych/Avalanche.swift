//
//  StakeableLockedInput.swift
//  
//
//  Created by Ostap Danylovych on 01.09.2021.
//

import Foundation

public struct StakeableLockedInput {
    public static let typeID: TypeID = PChainTypeID.stakeableLockedInput
    
    public let locktime: Date
    public let transferableInput: TransferableInput
    
    public init(locktime: Date, transferableInput: TransferableInput) {
        self.locktime = locktime
        self.transferableInput = transferableInput
    }
}

extension StakeableLockedInput: AvalancheEncodable {
    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.typeID, name: "typeID")
            .encode(locktime, name: "locktime")
            .encode(transferableInput, name: "transferableInput")
    }
}
