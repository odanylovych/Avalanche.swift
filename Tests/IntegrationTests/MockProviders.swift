//
//  MockProviders.swift
//  
//
//  Created by Ostap Danylovych on 26.01.2022.
//

import Foundation
import Avalanche

class SignatureProviderMock: AvalancheSignatureProvider {
    var accountsMock: ((
        AvalancheSignatureProviderAccountRequestType,
        @escaping (AvalancheSignatureProviderResult<AvalancheSignatureProviderAccounts>) -> Void
    ) -> Void)?
    var signTransactionMock: ((Any, @escaping (AvalancheSignatureProviderResult<Any>) -> Void) -> Void)?
    var signMessageMock: ((Data, Any, @escaping (AvalancheSignatureProviderResult<Signature>) -> Void) -> Void)?
    
    func accounts(type: AvalancheSignatureProviderAccountRequestType,
                  _ cb: @escaping (AvalancheSignatureProviderResult<AvalancheSignatureProviderAccounts>) -> Void) {
        accountsMock!(type, cb)
    }
    
    func sign<T: ExtendedUnsignedTransaction>(transaction: T,
                                              _ cb: @escaping (AvalancheSignatureProviderResult<T.Signed>) -> Void) {
        signTransactionMock!(transaction) { res in
            cb(res.map { $0 as! T.Signed })
        }
    }
    
    func sign<A: ExtendedAddressProtocol>(message: Data,
                                          address: A,
                                          _ cb: @escaping (AvalancheSignatureProviderResult<Signature>) -> Void) {
        signMessageMock!(message, address, cb)
    }
}
