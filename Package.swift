// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WINRSDK",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "WINRSDK",
            targets: ["WINRSDK"]
        )
    ],
    targets: [
        .target(
            name: "WINRSDK",
            path: "WINRSDK",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "WINRSDKTests",
            dependencies: ["WINRSDK"],
            path: "WINRSDKTests"
        )
    ]
)

