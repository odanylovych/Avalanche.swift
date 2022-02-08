//
//  EthAddress.swift
//  
//
//  Created by Yehor Popovych on 26.08.2021.
//

import Foundation
#if !COCOAPODS
import web3swift
#endif

public struct EthAccount: AccountProtocol, ExtendedAddressProtocol, Equatable, Hashable {
    public typealias Addr = EthereumAddress
    public typealias Base = EthereumAddress
    
    public var address: EthereumAddress { try! EthereumAddress(pubKey: pubKey) }
    public let path: Bip32Path
    public let pubKey: Data
    
    public var index: UInt32 { accountIndex }
    public var isChange: Bool { false }
    public var accountIndex: UInt32 { path.accountIndex! }
    
    public init(pubKey: Data, path: Bip32Path) throws {
        guard path.isValidEthereumAccount else {
            throw AccountError.badBip32Path(path: path)
        }
        self.path = path
        self.pubKey = pubKey
    }
    
    public func avalancheAddress(hrp: String, chainId: String) throws -> Address {
        try Address(pubKey: pubKey, hrp: hrp, chainId: chainId)
    }
}

extension EthereumAddress {
    public init(pubKey: Data) throws {
        guard let raw = Algos.Ethereum.address(from: pubKey),
              let address = Self(raw) else {
            throw AccountError.badPublicKey(key: pubKey)
        }
        self = address
    }
}

extension EthereumAddress: AddressProtocol {
    public typealias Extended = EthAccount
    
    public func verify(message: Data, signature: Signature) -> Bool {
        Algos.Ethereum.verify(address: addressData,
                              message: message,
                              signature: signature.raw) ?? false
    }
}

extension EthereumAddress: AvalancheCodable {
    public static let rawAddressSize = 20
    
    public init(from decoder: AvalancheDecoder) throws {
        self.init(try decoder.decode(size: Self.rawAddressSize))!
    }

    public func encode(in encoder: AvalancheEncoder) throws {
        try encoder.encode(addressData, size: Self.rawAddressSize)
    }
}
