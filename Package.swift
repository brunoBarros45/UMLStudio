// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "UMLStudio",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "UMLDomain", targets: ["UMLDomain"]),
        .library(name: "UMLApplication", targets: ["UMLApplication"]),
        .library(name: "UMLInfrastructure", targets: ["UMLInfrastructure"]),
        .executable(name: "UMLStudioApp", targets: ["UMLStudioApp"])
    ],
    targets: [
        .target(
            name: "UMLDomain",
            path: "Sources/UMLDomain"
        ),
        .target(
            name: "UMLApplication",
            dependencies: ["UMLDomain"],
            path: "Sources/UMLApplication"
        ),
        .target(
            name: "UMLInfrastructure",
            dependencies: ["UMLDomain", "UMLApplication"],
            path: "Sources/UMLInfrastructure"
        ),
        .executableTarget(
            name: "UMLStudioApp",
            dependencies: ["UMLDomain", "UMLApplication", "UMLInfrastructure"],
            path: "Sources/UMLStudioApp"
        ),
        .testTarget(
            name: "UMLStudioTests",
            dependencies: ["UMLDomain", "UMLApplication", "UMLInfrastructure"],
            path: "Tests/UMLStudioTests"
        )
    ]
)
