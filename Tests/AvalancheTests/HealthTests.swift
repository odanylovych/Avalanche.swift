import XCTest
@testable import Avalanche
    
final class HealthTests: AvalancheTestCase {
    func testGetLiveness() {
        let expect = expectation(description: "getLiveness")
        
        ava.health.getLiveness() { result in
            XCTAssertEqual((try? result.get())?.healthy, .some(true))
            expect.fulfill()
        }
        wait(for: [expect], timeout: 10)
    }
}
