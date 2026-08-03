// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BigDockLocker",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "BigDockLocker",
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Info.plist"
                ])
            ]
        ),
        .testTarget(
            name: "BigDockLockerTests",
            dependencies: ["BigDockLocker"]
        )
    ]
)
