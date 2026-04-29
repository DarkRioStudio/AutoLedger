// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AutoLedgerCoreKit",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .watchOS(.v11),
    ],
    products: [
        .library(name: "AutoLedgerCoreKit", targets: ["AutoLedgerCoreKit"]),
    ],
    targets: [
        .target(
            name: "AutoLedgerCoreKit",
            dependencies: [],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
