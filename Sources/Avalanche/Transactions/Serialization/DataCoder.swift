//
//  DataCoder.swift
//  
//
//  Created by Ostap Danylovych on 09.07.2022.
//

import Foundation

public protocol DataCoder {
    var encoding: ApiDataEncoding { get }
    
    func encode(_ data: Data) -> String
    func decode(_ value: String) -> Data?
}

public struct HexNCDataCoder: DataCoder {
    public var encoding: ApiDataEncoding = .hexnc
    
    public func encode(_ data: Data) -> String {
        data.hex()
    }
    
    public func decode(_ value: String) -> Data? {
        Data(hex: value)
    }
}
