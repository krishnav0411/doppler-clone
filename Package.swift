// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DopplerClone",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "DopplerCore", targets: ["DopplerCore"]),
        .library(name: "DopplerUI", targets: ["DopplerUI"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "DopplerCore",
            dependencies: []
        ),
        .target(
            name: "DopplerUI",
            dependencies: ["DopplerCore"]
        ),
    ]
)
