//
//  StakeableLockedOutput.swift
//  
//
//  Created by Ostap Danylovych on 01.09.2021.
//

import Foundation

public class StakeableLockedOutput: Output, AvalancheDecodable {
    override public class var typeID: TypeID { PChainTypeID.stakeableLockedOutput }
    
    public let transferableOutput: TransferableOutput
    
    public init(locktime: Date, transferableOutput: TransferableOutput) throws {
        self.transferableOutput = transferableOutput
        try super.init(
            addresses: transferableOutput.output.addresses,
            locktime: locktime,
            threshold: transferableOutput.output.threshold
        )
    }
    
    convenience required public init(amount: UInt64, locktime: Date, threshold: UInt32, addresses: [Address]) throws {
        fatalError("Not supported")
    }
    
    convenience required public init(dynamic decoder: AvalancheDecoder, typeID: UInt32) throws {
        guard typeID == Self.typeID.rawValue else {
            throw AvalancheDecoderError.dataCorrupted(
                typeID,
                AvalancheDecoderError.Context(path: decoder.path, description: "Wrong typeID")
            )
        }
        try self.init(
            locktime: try decoder.decode(name: "locktime"),
            transferableOutput: try decoder.decode(name: "transferableOutput")
        )
    }
    
    override public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.typeID, name: "typeID")
            .encode(locktime, name: "locktime")
            .encode(transferableOutput, name: "transferableOutput")
    }
}
