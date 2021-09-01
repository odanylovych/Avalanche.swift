//
//  TransactionError.swift
//  
//
//  Created by Ostap Danylovych on 27.08.2021.
//

import Foundation

public enum MalformedTransactionError: Error {
    case wrongValue(Any, name: String, message: String)
    case outOfRange(Any, expected: ClosedRange<Int>, name: String, description: String = "")
}
