//
//  DecoderError.swift
//  
//
//  Created by Ostap Danylovych on 15.09.2021.
//

import Foundation

public enum AvalancheDecoderError: Error {
    case noDataLeft
    case dataCorrupted(Any, description: String)
}
