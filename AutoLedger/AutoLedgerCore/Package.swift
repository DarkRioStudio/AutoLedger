// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AutoLedgerCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10),
    ],
    products: [
        .library(name: "AutoLedgerCore", targets: ["AutoLedgerCore"]),
    ],
    targets: [
        .target(name: "AutoLedgerCore"),
        .testTarget(
            name: "AutoLedgerCoreTests",
            dependencies: ["AutoLedgerCore"]
        ),
    ]
)
