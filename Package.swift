// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "CodexQuotaBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "CodexQuotaBar", targets: ["CodexQuotaBar"])
    ],
    targets: [
        .executableTarget(
            name: "CodexQuotaBar"
        ),
        .testTarget(
            name: "CodexQuotaBarTests",
            dependencies: ["CodexQuotaBar"]
        )
    ]
)
