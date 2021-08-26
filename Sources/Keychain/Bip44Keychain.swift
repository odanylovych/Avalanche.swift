//
//  File.swift
//  
//
//  Created by Daniel Leping on 09/01/2021.
//

import Foundation
#if !COCOAPODS
import Avalanche
#endif

public class AvalancheBip44Keychain {
    private var _rootKey: KeyPair
    internal var _avaCache: Dictionary<UInt32, KeyPair>
    internal var _ethCache: Dictionary<UInt32, KeyPair>
    
    public convenience init(seed: Data) throws {
        try self.init(root: KeyPair(seed: seed))
    }
    
    public init(root: KeyPair) throws {
        guard root.chainCode != nil else {
            throw KeyPair.Error.badChainCodeLength(length: 0)
        }
        self._avaCache = [:]
        self._ethCache = [:]
        self._rootKey = root
    }
    
    @discardableResult
    public func addEthereumAccount(index: UInt32) throws -> KeyPair {
        let b44 = Bip32Path.prefixEthereum
        let kp = try _rootKey
            .derive(index: b44.path[0], hard: true)
            .derive(index: b44.path[1], hard: true)
            .derive(index: index, hard: true)
            .derive(index: 0, hard: false)
            .derive(index: 0, hard: false)
        _ethCache[index] = kp
        return kp
    }
    
    @discardableResult
    public func addAvalancheAccount(index: UInt32) throws -> KeyPair {
        let b44 = Bip32Path.prefixAvalanche
        let kp = try _rootKey
            .derive(index: b44.path[0], hard: true)
            .derive(index: b44.path[1], hard: true)
            .derive(index: index, hard: true)
        _avaCache[index] = kp
        return kp
    }
    
    public func avalancheAccounts() -> [Account] {
        _avaCache.map { (idx, kp) in
            let path = try! Bip32Path.prefixAvalanche.appending(idx, hard: true)
            return try! Account(pubKey: kp.publicKey,
                                chainCode: kp.chainCode!,
                                path: path)
        }
    }
    
    public func ethereumAccounts() -> [EthAccount] {
        _ethCache.map { (idx, kp) in
            let path = try! Bip32Path.prefixEthereum
                .appending(idx, hard: true)
                .appending(0, hard: false)
                .appending(0, hard: false)
            return try! EthAccount(pubKey: kp.publicKey, path: path)
        }
    }
}
