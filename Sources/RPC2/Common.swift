//
//  File.swift
//  
//
//  Created by Daniel Leping on 14/12/2020.
//

/// utils

struct WeakRef<T: AnyObject> {
    weak var ref: T?
}

/// core types

public typealias Callback<Success, Failure: Error> = (Result<Success, Failure>)->Void

public protocol FactoryBase {
    associatedtype Connection
}

public enum ConnectableState {
    case connected
    case disconnected
    case connecting
    case disconnecting
}

public protocol Connectable {
    var connected: ConnectableState {get}
    
    func connect()
    func disconnect()
}
