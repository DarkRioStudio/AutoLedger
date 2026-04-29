// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AutoLedgerCore",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
        .watchOS(.v11),
    ],
    products: [
        .library(name: "AutoLedgerCore", targets: ["AutoLedgerCore"]),
    ],
    targets: [
        .target(name: "AutoLedgerCore"),
    ]
)
