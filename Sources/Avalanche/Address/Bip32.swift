//
//  Bip32.swift
//  
//
//  Created by Yehor Popovych on 25.08.2021.
//

import Foundation

public struct Bip32Path: Equatable, Hashable {
    public enum Error: Swift.Error {
        case invalidMarker(String)
        case pathTooShort(Int)
        case shouldBeHard(UInt32)
        case shouldBeSoft(UInt32)
        case cantParse(String)
    }
    
    public let path: [UInt32]
    
    public init(path: [UInt32]) {
        self.path = path
    }
    
    public func appending(_ index: UInt32, hard: Bool = false) throws -> Self {
        var index = index
        if !hard && index >= Self.hard {
            throw Error.shouldBeSoft(index)
        }
        if hard && index < Self.hard {
            index += Self.hard
        }
        if let prev = path.last, prev < Self.hard && hard {
            throw Error.shouldBeSoft(index)
        }
        return Bip32Path(path: self.path + [index])
    }
    
    public static let prefixEthereum = Bip32Path(path: [Self.hard + 44, Self.hard + 60])
    public static let prefixAvalanche = Bip32Path(path: [Self.hard + 44, Self.hard + 9000])
    
    public static let hard: UInt32 = 0x80000000
}

extension Bip32Path {
    public var isValidEthereumAccount: Bool {
        path.count == 5 &&
            Array(path.prefix(2)) == Self.prefixEthereum.path &&
            path[3] == 0 && path[4] == 0 && path[2] >= Self.hard
    }
    
    public var isValidAvalancheAccount: Bool {
        path.count == 3 &&
            Array(path.prefix(2)) == Self.prefixAvalanche.path &&
            path[3] >= Self.hard
    }
    
    public var isValidAvalancheAddress: Bool {
        path.count == 5 &&
            Array(path.prefix(2)) == Self.prefixAvalanche.path &&
            path[2] >= Self.hard && path[3] < Self.hard && path[4] < Self.hard
    }
}


extension Bip32Path {
    public init(parsing str: String) throws {
        let parts = str.split(separator: "/").map{String($0)}
        guard parts.first == "m" else {
            throw Error.invalidMarker(String(parts.first ?? ""))
        }
        guard parts.count > 1 else {
            throw Error.pathTooShort(parts.count)
        }
        self = try parts
            .dropFirst()
            .enumerated()
            .reduce(Bip32Path(path: [])) { (b32, part) in
                var hard: Bool
                var int: UInt32
                if part.element.hasSuffix("'") {
                    guard let parsed = UInt32(String(part.element.dropLast()), radix: 10) else {
                        throw Error.cantParse(part.element)
                    }
                    hard = true
                    int = parsed
                } else {
                    guard let parsed = UInt32(part.element, radix: 10) else {
                        throw Error.cantParse(part.element)
                    }
                    hard = false
                    int = parsed
                }
                if part.offset < 3 && !hard {
                    throw Error.shouldBeHard(int)
                }
                return try b32.appending(int, hard: hard)
            }
    }
}
