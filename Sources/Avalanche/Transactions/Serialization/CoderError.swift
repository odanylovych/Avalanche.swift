//
//  CoderError.swift
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

public enum AvalancheDecoderError: Error {
    public struct Context {
        public let path: [String]
        public let description: String
        
        public init(path: [String], description: String = "") {
            self.path = path
            self.description = description
        }
    }
    
    case noDataLeft(Context)
    case dataCorrupted(Any, Context)
}

struct AvalancheCoderPath {
    var path: [String]
    
    init(_ path: [String] = []) {
        self.path = path
    }
    
    mutating func push<T>(_ element: T) {
        path.append(String(describing: element))
    }
    
    mutating func push<T>(_ element: T, name: String) {
        path.append("\(name): \(String(describing: element))")
    }
    
    mutating func push<T>(_ element: T, size: Int) {
        path.append("\(String(describing: element))[\(size)]")
    }
    
    mutating func pop() {
        let _ = path.popLast()
    }
}
