//
//  SignatureProvider.swift
//  
//
//  Created by Yehor Popovych on 25.08.2021.
//

import Foundation

public enum AvalancheSignatureProviderError: Error {
    case accountNotFound(account: Bip32Path)
    case signingFailed(address: Bip32Path, reason: String)
    case transport(error: Error)
    case rejected
}

public enum AvalancheSignatureProviderAccountRequestType: Hashable, Equatable {
    case avalancheOnly
    case ethereumOnly
    case both
}

public typealias AvalancheSignatureProviderResult<T> = Result<T, AvalancheSignatureProviderError>
public typealias AvalancheSignatureProviderAccounts = (avalanche: [Account], ethereum: [EthAccount])

public protocol AvalancheSignatureProvider {
    func accounts(type: AvalancheSignatureProviderAccountRequestType,
        _ cb: @escaping (AvalancheSignatureProviderResult<AvalancheSignatureProviderAccounts>) -> Void)
    
    func sign<T: ExtendedUnsignedTransaction>(
        transaction: T,
        _ cb: @escaping (AvalancheSignatureProviderResult<T.Signed>) -> Void)
    
    func sign(ethereum message: Data,
              account: EthAccount,
              _ cb: @escaping (AvalancheSignatureProviderResult<Signature>) -> Void)
}