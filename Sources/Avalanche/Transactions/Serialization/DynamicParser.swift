//
//  DynamicParser.swift
//  
//
//  Created by Ostap Danylovych on 17.09.2021.
//

import Foundation

public protocol DynamicTypeParser {
    func decode(input decoder: AvalancheDecoder) throws -> Input
    func decode(output decoder: AvalancheDecoder) throws -> Output
    func decode(operation decoder: AvalancheDecoder) throws -> Operation
    func decode(credential decoder: AvalancheDecoder) throws -> Credential
    func decode(transaction decoder: AvalancheDecoder) throws -> UnsignedAvalancheTransaction
}
