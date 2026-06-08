// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NatureRemoMenuBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "NatureRemoMenuBar", targets: ["NatureRemoMenuBar"])
    ],
    targets: [
        .executableTarget(
            name: "NatureRemoMenuBar",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("Security")
            ]
        )
    ]
)
