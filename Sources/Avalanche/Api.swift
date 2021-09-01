//
//  Api.swift
//  
//
//  Created by Yehor Popovych on 9/5/20.
//

import Foundation

public protocol AvalancheApi {
    associatedtype Info: AvalancheApiInfo
    
    init(avalanche: AvalancheCore, networkID: NetworkID, hrp: String, info: Info)
    
    static var id: String { get }
}

extension AvalancheApi {
    public static var id: String {
        return String(describing: self)
    }
}

public protocol AvalancheApiInfo {
    var apiPath: String { get }
}

public protocol AvalancheVMApiInfo: AvalancheApiInfo {
    var blockchainID: BlockchainID { get }
    var alias: String? { get }
    var vm: String { get }
}

public class AvalancheBaseApiInfo: AvalancheVMApiInfo {
    public let blockchainID: BlockchainID
    public let alias: String?
    public let vm: String
    
    public init(blockchainID: BlockchainID, alias: String?, vm: String) {
        self.blockchainID = blockchainID
        self.alias = alias
        self.vm = vm
    }
    
    public var apiPath: String {
        return "/ext/bc/\(alias ?? blockchainID.cb58())"
    }
}
