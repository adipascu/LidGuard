// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LidGuard",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "CBluetoothShim"),
        .executableTarget(
            name: "LidGuard",
            dependencies: ["CBluetoothShim"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreWLAN"),
                .linkedFramework("IOBluetooth"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
    ]
)
