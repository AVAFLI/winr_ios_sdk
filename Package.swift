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
    dependencies: [
        .package(url: "https://github.com/airbnb/lottie-ios.git", from: "4.3.0")
    ],
    targets: [
        .target(
            name: "WINRSDK",
            dependencies: [
                .product(name: "Lottie", package: "lottie-ios")
            ],
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

