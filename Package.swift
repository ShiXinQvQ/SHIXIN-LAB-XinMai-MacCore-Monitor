// swift-tools-version: 6.0
// Copyright (C) 2026 SHIXIN LAB / Shixin
// SPDX-License-Identifier: GPL-3.0-or-later

import PackageDescription

let package = Package(
    name: "ShixinStressPower",
    defaultLocalization: "zh-Hans",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "ShixinStressPowerCore", targets: ["ShixinStressPowerCore"]),
        .library(
            name: "ShixinNetworkDiagnosticsCore",
            targets: ["ShixinNetworkDiagnosticsCore"]
        ),
        .executable(name: "ShixinStressPower", targets: ["ShixinStressPower"]),
        .executable(name: "ShixinStressPowerHelper", targets: ["ShixinStressPowerHelper"]),
        .executable(name: "ShixinStressPowerSelfTest", targets: ["ShixinStressPowerSelfTest"])
    ],
    targets: [
        .target(
            name: "ShixinStressPowerHardwareBridge",
            path: "Sources/ShixinStressPowerHardwareBridge",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedFramework("IOKit")
            ]
        ),
        .target(
            name: "ShixinStressPowerCore",
            dependencies: ["ShixinStressPowerHardwareBridge"],
            path: "Sources/ShixinStressPowerCore"
        ),
        .target(
            name: "ShixinNetworkDiagnosticsCore",
            path: "Sources/ShixinNetworkDiagnosticsCore"
        ),
        .executableTarget(
            name: "ShixinStressPower",
            dependencies: [
                "ShixinStressPowerCore",
                "ShixinNetworkDiagnosticsCore"
            ],
            path: "Sources/ShixinStressPower",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "ShixinStressPowerHelper",
            dependencies: ["ShixinStressPowerCore"],
            path: "Sources/ShixinStressPowerHelper"
        ),
        .executableTarget(
            name: "ShixinStressPowerSelfTest",
            dependencies: [
                "ShixinStressPowerCore",
                "ShixinNetworkDiagnosticsCore"
            ],
            path: "Sources/ShixinStressPowerSelfTest"
        )
    ],
    swiftLanguageModes: [.v5]
)
