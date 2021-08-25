// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Avalanche",
    platforms: [.iOS(.v11), .macOS(.v10_12)],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "Avalanche",
            targets: ["Avalanche"]),
        .library(
            name: "AvalancheAlgos",
            targets: ["AvalancheAlgos"]),
        .library(
            name: "AvalancheKeychain",
            targets: ["AvalancheKeychain"]),
        .library(
            name: "Bech32",
            targets: ["Bech32"]),
        .library(
            name: "Base58",
            targets: ["Base58"]),
        .library(
            name: "RPC",
            targets: ["RPC"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/tesseract-one/WebSocket.swift.git", from: "0.0.7"),
        .package(url: "https://github.com/attaswift/BigInt.git", from: "5.2.0"),
        .package(url: "https://github.com/tesseract-one/Serializable.swift.git", from: "0.2.0"),
        .package(url: "https://github.com/Boilertalk/secp256k1.swift.git", from: "0.1.0"),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", .exact("1.4.1")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "Avalanche",
            dependencies: ["RPC", "Serializable", "BigInt", "AvalancheAlgos"]),
        .target(
            name: "AvalancheAlgos",
            dependencies: ["secp256k1", "CryptoSwift", "Bech32"],
            path: "Sources/Algos"),
        .target(
            name: "AvalancheKeychain",
            dependencies: ["AvalancheAlgos", "Base58", "Avalanche"],
            path: "Sources/Keychain"),
        .target(
            name: "Bech32",
            dependencies: []),
        .target(
            name: "Base58",
            dependencies: ["CryptoSwift", "BigInt"]),
        .target(
            name: "RPC",
            dependencies: ["WebSocket"]),
        .testTarget(
            name: "AvalancheTests",
            dependencies: ["Avalanche"]),
        .testTarget(
            name: "KeychainTests",
            dependencies: ["AvalancheKeychain"]),
        .testTarget(
            name: "AlgosTests",
            dependencies: ["AvalancheAlgos"]),
        .testTarget(
            name: "Bech32Tests",
            dependencies: ["Bech32"]),
        .testTarget(
            name: "Base58Tests",
            dependencies: ["Base58"]),
        .testTarget(
            name: "RPCTests",
            dependencies: ["RPC", "Serializable"]),
    ]
)


