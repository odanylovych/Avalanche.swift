//
//  StakeableLockedInput.swift
//  
//
//  Created by Ostap Danylovych on 01.09.2021.
//

import Foundation

public class StakeableLockedInput: Input, AvalancheDecodable {
    override public class var typeID: TypeID { PChainTypeID.stakeableLockedInput }
    
    public let locktime: Date
    public let transferableInput: TransferableInput
    
    public init(locktime: Date, transferableInput: TransferableInput) {
        self.locktime = locktime
        self.transferableInput = transferableInput
        super.init(addressIndices: transferableInput.input.addressIndices)
    }
    
    convenience required public init(dynamic decoder: AvalancheDecoder, typeID: UInt32) throws {
        guard typeID == Self.typeID.rawValue else {
            throw AvalancheDecoderError.dataCorrupted(
                typeID,
                AvalancheDecoderError.Context(path: decoder.path, description: "Wrong typeID")
            )
        }
        self.init(
            locktime: try decoder.decode(name: "locktime"),
            transferableInput: try decoder.decode(name: "transferableInput")
        )
    }
    
    override public func credentialType() -> Credential.Type {
        SECP256K1Credential.self
    }
    
    override public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(Self.typeID, name: "typeID")
            .encode(locktime, name: "locktime")
            .encode(transferableInput, name: "transferableInput")
    }
    
    override public func equalTo(rhs: Input) -> Bool {
        guard let rhs = rhs as? Self else { return false }
        return locktime == rhs.locktime
        && transferableInput == rhs.transferableInput
        && addressIndices == rhs.addressIndices
    }
}
