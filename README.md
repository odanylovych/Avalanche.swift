# Avalanche.swift - The Avalanche Platform Swift Library

[![GitHub license](https://img.shields.io/badge/license-Apache%202.0-lightgrey.svg)](LICENSE)
[![Build Status](https://github.com/tesseract-one/Avalanche.swift/workflows/Build%20%26%20Tests/badge.svg?branch=master)](https://github.com/tesseract-one/Avalanche.swift/actions?query=workflow%3ABuild%20%26%20Tests+branch%3Amaster)
[![GitHub release](https://img.shields.io/github/release/tesseract-one/Avalanche.swift.svg)](https://github.com/tesseract-one/sAvalanche.swift/releases)
[![SPM compatible](https://img.shields.io/badge/SwiftPM-Compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![CocoaPods version](https://img.shields.io/cocoapods/v/Avalanche.svg)](https://cocoapods.org/pods/Avalanche)
![Platform OS X | iOS](https://img.shields.io/badge/platform-OS%20X%20%7C%20iOS-orange.svg)

## Overview 

Avalanche.swift is a Swift Library for interfacing with the Avalanche Platform. The library allows one to issue commands to the Avalanche node APIs. 

The APIs currently supported are:

 * [x] Admin API
 * [x] Auth API
 * [x] AVM API (X-Chain)
 * [x] EVM API (C-Chain)
 * [x] Health API
 * [x] Info API
 * [x] IPC API
 * [x] Keystore API
 * [x] Metrics API
 * [x] PlatformVM API (P-Chain)

We built Avalanche.swift with ease of use in mind. With this library, any Swift developer is able to interact with a node on the Avalanche Platform who has enabled their API endpoints for the developer's consumption. We keep the library up-to-date with the latest changes in the [Avalanche Platform Specification](https://docs.avax.network). 

  Using Avalanche.swift, developers can:

  * Locally manage private keys
  * Retrieve balances on addresses
  * Get UTXOs for addresses
  * Build and sign transactions
  * Issue signed transactions to the X-Chain
  * Create a Subnetwork
  * Administer a local node
  * Retrieve Avalanche network information from a node
  * Call smart-contracts on C-Chain

### Requirements

Avalanche.swift deploys to macOS 10.12+, iOS 11+ and requires Swift 5.4 or higher to compile.

### Installation

- **Swift Package Manager:**
  Add this to the dependency section of your `Package.swift` manifest:

    ```Swift
    .package(url: "https://github.com/tesseract-one/Avalanche.swift.git", from: "0.0.1")
    ```

- **CocoaPods:** Put this in your `Podfile`:

    ```Ruby
    pod 'Avalanche', '~> 0.0.1'
    ```

## Examples

### Calling APIs

The APIs are accessible fields on an Avalanche instance (info, health, etc.). Here is an example for a `info.getNetworkID` method call. The methods in the library are identical to the methods described in the main API [documentation](https://docs.avax.network/build/avalanchego-apis):

```Swift
let ava = Avalanche(url: URL(string: "https://api.avax-test.network")!, networkID: .test)
    
ava.info.getNetworkID { result in
    switch result {
    case .success(let id):
        print("ID is: ", id)
    case .failure(let error):
        print("Error occured: ", error)
    }
}
```

### Managing Private Keys

Avalanche.swift comes with its own In-App Bip44 Keychain. This KeyChain is used in the functions of the API, enabling them to sign using keys it's registered. It can be accessed by adding dependency to the `AvalancheKeychain` in case of SPM or enabling `Avalanche/Keychain` feature in case of CocoaPods.

The first step in this process is to create an instance of `AvalancheBip44Keychain` and pass it to `Avalanche` constructor.

```Swift
import Avalanche
// Not needed for CocoaPods
import AvalancheKeychain

// Creating root Bip44 key from data
let rootKey = try! KeyPair(key: "PrivateKey-24jUJ9vZexUM6expyMcT48LBx27k1m7xpraoV62oSQAHdziao5")

// Creating keychain with root key
let keychain = AvalancheBip44Keychain(root: rootKey)

// Creating Avalanche object
let ava = Avalanche(url: URL(string: "http://localhost:9650")!, networkID: .local, signatureProvider: keychain) // connects to localhost with network id 12345 and bip44 keychain

// Adding account with index 0 for chains. This will generate account with proper Bip44 path and save it in cache.
keychain.addEthereumAccount(index: 0)
keychain.addAvalancheAccount(index: 0)
```

### Retrieving addresses from blockchain

Before using APIs we have to retreive used addresses for registered accounts. It can be done through API keychains.

```Swift
ava.xChain.keychain.fetch() { _ in
    let accounts = ava.xChain.keychain.fetchedAccounts()
    print("xChain fetched addresses: \(ava.xChain.keychain.get(cached: accounts[0]))")
}
ava.pChain.keychain.fetch() { _ in 
    let accounts = ava.pChain.keychain.fetchedAccounts()
    print("pChain fetched addresses: \(ava.pChain.keychain.get(cached: accounts[0]))")
}
```

### Performing transaction

#### Sending transactions with helper methods

For convenience we provided a set of the helper methods for creating and signing transactions. This methods allow you to pass account or username and password and will create transaction for you in case of account.

```Swift

// Get our account from keychain
let from = ava.xChain.keychain.fetchedAccounts()[0]

// Asset ID
let assetId = AssetID(cb58: "23wKfz3viWLmjWo2UZ7xWegjvnZFenGAVkouwQCeB9ubPXodG6")!

// Recipient address
let friendsAddress = Address(bech: "X-avax1k26jvfdzyukms95puxcceyzsa3lzwf5ftt0fjk")

ava.xChain.send(amount: 1000, assetID: assetId, to: friendsAddress, credentials: .account(from)) { res in
    print("Resul: \(res)")
}
```

#### Building transaction manually


#### C-Chain support

Ethereum C-Chain APIs implemented with 

## License

Avalanche.swift can be used, distributed and modified under [the Apache 2.0 license](LICENSE).
