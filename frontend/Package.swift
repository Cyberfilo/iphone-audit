// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "iSpow",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "iSpow", targets: ["iSpow"])
    ],
    targets: [
        .executableTarget(
            name: "iSpow",
            path: "Sources/iSpow"
        )
    ]
)
