//
//  EncoderError.swift
//  
//
//  Created by Ostap Danylovych on 26.08.2021.
//

import Foundation

public enum AvalancheEncoderError: Error {
    public struct Context {
        public let path: [String]
        public let description: String
        
        public init(path: [String], description: String = "") {
            self.path = path
            self.description = description
        }
    }
    
    case invalidValue(Any, Context)
    case wrongFixedArraySize(Any, actual: Int, expected: Int, Context)
}

struct AvalancheEncoderContext {
    var path: [String]
    
    init(_ path: [String] = []) {
        self.path = path
    }
    
    mutating func push<T>(_ element: T) {
        path.append(String(describing: element))
    }
    
    mutating func pop() {
        let _ = path.popLast()
    }
}
