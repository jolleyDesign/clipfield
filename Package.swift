// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Clipfield",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Clipfield",
            path: "Sources/Clipfield",
            swiftSettings: [
                // Keep Swift 5 concurrency semantics for an AppKit/SwiftUI app to avoid
                // fighting strict-concurrency diagnostics; UI code is @MainActor anyway.
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
