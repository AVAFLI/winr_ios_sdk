// swift-tools-version: 5.9
import PackageDescription
import Foundation

var targets: [Target] = [
    .target(
        name: "WINRSDK",
        path: "WINRSDK",
        resources: [
            .process("Resources")
        ]
    )
]

// The public mirror ships without the test suite, and a declared test target
// whose directory is missing makes `swift build` fail in a fresh clone of the
// mirror. Declare it only where the directory actually exists (the private
// monorepo), so this one manifest is correct in both repos.
if FileManager.default.fileExists(atPath: Context.packageDirectory + "/WINRSDKTests") {
    targets.append(
        .testTarget(
            name: "WINRSDKTests",
            dependencies: ["WINRSDK"],
            path: "WINRSDKTests"
        )
    )
}

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
    targets: targets
)
