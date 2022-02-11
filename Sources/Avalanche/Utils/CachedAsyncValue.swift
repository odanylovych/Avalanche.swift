//
//  CachedAsyncValue.swift
//  
//
//  Created by Yehor Popovych on 11.02.2022.
//

import Foundation

private let _syncQueue = DispatchQueue(
    label: "AsyncValueSyncQueue", target: .global()
)

public class CachedAsyncValue<V, E: Error> {
    private let getter: ((Result<V, E>) -> ()) -> ()
    private var value: Optional<V>
    
    public init(getter: @escaping ((Result<V, E>) -> ()) -> ()) {
        self.getter = getter
        self.value = nil
    }
    
    public func get(force: Bool = false, _ cb: @escaping (Result<V,E>) -> ()) {
        syncQueue.async {
            if let val = self.value, !force {
                cb(.success(val))
                return
            }
            self.getter() { res in
                switch res {
                case .success(let val):
                    self.syncQueue.async { self.value = val }
                    cb(.success(val))
                case .failure(let err):
                    self.syncQueue.async { self.value = nil }
                    cb(.failure(err))
                }
            }
        }
    }
    
    private var syncQueue: DispatchQueue {
        return _syncQueue
    }
}
