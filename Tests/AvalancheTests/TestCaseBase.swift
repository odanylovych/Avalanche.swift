//
//  TestCaseBase.swift
//  
//
//  Created by Yehor Popovych on 12/27/20.
//

import XCTest
import Avalanche

class AvalancheTestCase: XCTestCase {
    private static let env = ProcessInfo.processInfo.environment
    private static let privateNodeApisEnabled = Bool(env["AVALANCHE_PRIVATE_NODE_APIS_ENABLED"] ?? "false")!
    
    private static func test(_ test: AvalancheTestCase.Type, enabled: Bool) -> (AvalancheTestCase.Type, Bool) {
        (test, enabled)
    }
    
    private static func _registry(_ fac: ()->[(AvalancheTestCase.Type, Bool)]) -> [String: Bool] {
        Dictionary(uniqueKeysWithValues: fac().map {(String(describing: $0.0), $0.1)})
    }
    
    private static var testEnabled: Bool {
        registry[String(describing: self)] ?? true //enabled by default
    }
    
    static let registry = _registry {
        [
         test(AdminTests.self, enabled: privateNodeApisEnabled),
         test(AuthTests.self, enabled: privateNodeApisEnabled),
         test(HealthTests.self, enabled: privateNodeApisEnabled),
         test(InfoTests.self, enabled: privateNodeApisEnabled),
         test(IPCTests.self, enabled: privateNodeApisEnabled),
         test(KeystoreTests.self, enabled: privateNodeApisEnabled),
         test(MetricsTests.self, enabled: privateNodeApisEnabled),
         test(TransactionsTests.self, enabled: true),
        ]
    }
    
    var ava:Avalanche!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        try XCTSkipUnless(Self.testEnabled, "Test disabled in config")
        
        self.ava = Avalanche(url: URL(string: "https://api.avax-test.network")!, networkID: .test)
    }
}
