//
//  TransactionError.swift
//  
//
//  Created by Ostap Danylovych on 27.08.2021.
//

import Foundation
#if !COCOAPODS
import web3swift
#endif

public enum MalformedTransactionError: Error {
    case wrongValue(Any, name: String, message: String)
    case outOfRange(Any, expected: ClosedRange<Int>, name: String, description: String = "")
}

public enum TransactionBuilderError: Error {
    case insufficientFunds
    case gooseEggCheckError
}

public enum ExtendedAvalancheTransactionError: Error {
    case noSuchSignature(Address, in: [Address: Signature])
    case noSuchPath(Address, in: [Address: Address.Extended])
}

public enum EthereumTransactionError: Error {
    case encodeError
    case noSignature(for: EthereumAddress)
}
