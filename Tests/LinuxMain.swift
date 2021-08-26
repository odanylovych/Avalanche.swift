import XCTest

import AvalancheTests
import Base58Tests
import Bech32Tests
import RPCTests

var tests = [XCTestCaseEntry]()
tests += AvalancheTests.__allTests()
tests += Base58Tests.__allTests()
tests += Bech32Tests.__allTests()
tests += RPCTests.__allTests()

XCTMain(tests)
