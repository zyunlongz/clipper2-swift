// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Clipper2-swift",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
    ],
    products: [
        .library(name: "Clipper2", targets: ["Clipper2"]),
    ],
    targets: [
        .target(
            name: "Clipper2",
            path: "Sources/Clipper2"
        ),
        .testTarget(
            name: "Clipper2Tests",
            dependencies: ["Clipper2"],
            path: "Tests/Clipper2Tests",
            resources: [.copy("Resources")]
        ),
    ]
)
