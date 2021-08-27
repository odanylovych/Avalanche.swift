//
//  EncoderError.swift
//  
//
//  Created by Ostap Danylovych on 26.08.2021.
//

import Foundation

public enum AvalancheEncoderError: Error {
    case invalidValue(Any)
    case wrongFixedArraySize(Any, actual: Int, expected: Int)
}
