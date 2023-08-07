// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "SwiftNRC",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
        .macCatalyst(.v13),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SwiftNRC",
            targets: ["SwiftNRC"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-syntax",
            branch: "main"),
    ],
    targets: [
        .target(
            name: "SwiftNRC",
            plugins: ["SwiftNRCMacrosPlugin"]
        ),
        .macro(
            name: "SwiftNRCMacrosPlugin",
            dependencies: [
                .product(
                    name: "SwiftSyntax",
                    package: "swift-syntax"
                ),
                .product(
                    name: "SwiftSyntaxMacros",
                    package: "swift-syntax"
                ),
                .product(
                    name: "SwiftOperators",
                    package: "swift-syntax"
                ),
                .product(
                    name: "SwiftParser",
                    package: "swift-syntax"
                ),
                .product(
                    name: "SwiftParserDiagnostics",
                    package: "swift-syntax"
                ),
                .product(
                    name: "SwiftCompilerPlugin",
                    package: "swift-syntax"
                ),
        ]),
        .testTarget(
            name: "SwiftNRCTests",
            dependencies: ["SwiftNRC"]),
    ]
)
