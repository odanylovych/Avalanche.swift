//
//  CChainTypeID.swift
//  
//
//  Created by Ostap Danylovych on 02.09.2021.
//

import Foundation

public enum CChainTypeID: UInt32, TypeID, CaseIterable {
    // Transactions
    case exportTransaction = 0x00000001
    case importTransaction = 0x00000000
}
