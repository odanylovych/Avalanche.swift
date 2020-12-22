//
//  File.swift
//  
//
//  Created by Daniel Leping on 19/12/2020.
//

import Foundation

public protocol Delegator {
    var delegate: AnyObject? {get set}
}

public protocol ConnectableDelegate {
    func state(_ state: ConnectableState)
}

public protocol ErrorDelegate {
    func error(_ error: ServiceError)
}

//ErrorDelegate
//StateDelegate
//ServiceDelegate
