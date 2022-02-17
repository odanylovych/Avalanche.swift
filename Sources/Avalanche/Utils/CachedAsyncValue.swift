//
//  CachedAsyncValue.swift
//  
//
//  Created by Yehor Popovych on 11.02.2022.
//

import Foundation

private let AsyncValueSyncQueue = DispatchQueue(
    label: "AsyncValueSyncQueue", target: .global()
)

public class CachedAsyncValue<V, E: Error> {
    public var getter: ((@escaping (Result<V, E>) -> ()) -> ())?
    private var value: Optional<V>
    private var callbacks: Array<(Result<V,E>) -> ()>
    
    public init(_ value: V? = nil,
                getter: ((@escaping (Result<V, E>) -> ()) -> ())? = nil) {
        self.getter = getter
        self.callbacks = []
        self.value = value
    }
    
    public func get(force: Bool = false,  _ cb: @escaping (Result<V,E>) -> ()) {
        AsyncValueSyncQueue.async {
            self.callbacks.append(cb)
            if let val = self.value, !force {
                self._fetched(res: .success(val))
            } else {
                if self.callbacks.count == 1 {
                    self._fetch()
                }
            }
        }
    }
    
    private func _fetch() {
        guard let getter = self.getter else {
            fatalError("CachedAsyncValueError: getter is not set")
        }
        getter() { res in
            AsyncValueSyncQueue.async {
                switch res {
                case .success(let val):
                    self.value = val
                    self._fetched(res: .success(val))
                case .failure(let err):
                    self.value = nil
                    self._fetched(res: .failure(err))
                }
            }
        }
    }
    
    // Should be called in the syncQueue
    private func _fetched(res: Result<V, E>) {
        let callbacks = self.callbacks
        self.callbacks.removeAll()
        DispatchQueue.global().async {
            for callback in callbacks {
                callback(res)
            }
        }
    }
}
