// swift-tools-version:5.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Avalanche",
    platforms: [.macOS(.v10_12), .iOS(.v11)],
    products: [
        .library(
            name: "Avalanche",
            targets: ["Avalanche"]),
        .library(
            name: "AvalancheKeychain",
            targets: ["AvalancheKeychain"])
    ],
    dependencies: [
        .package(name: "JsonRPC", url: "https://github.com/tesseract-one/JsonRPC.swift.git", .branch("main")),
        .package(name: "UncommonCrypto", url: "https://github.com/tesseract-one/UncommonCrypto.swift.git", from: "0.1.0"),
        .package(name: "Bech32", url: "https://github.com/tesseract-one/Bech32.swift.git", from: "1.1.0"),
        .package(url: "https://github.com/attaswift/BigInt.git", from: "5.2.0"),
        .package(name: "Serializable", url: "https://github.com/tesseract-one/Serializable.swift.git", from: "0.2.0"),
        .package(url: "https://github.com/odanylovych/web3swift.git", .branch("signature-provider"))
    ],
    targets: [
        .target(
            name: "Avalanche",
            dependencies: [
                "JsonRPC",  "BigInt", "web3swift",
                "Bech32", "Serializable", "UncommonCrypto"
            ]),
        .target(
            name: "AvalancheKeychain",
            dependencies: ["Avalanche"],
            path: "Sources/Keychain"),
        .testTarget(
            name: "AvalancheTests",
            dependencies: ["Avalanche"]),
        .testTarget(
            name: "KeychainTests",
            dependencies: ["AvalancheKeychain"]),
        .testTarget(
            name: "IntegrationTests",
            dependencies: ["AvalancheKeychain"]),
    ]
)


