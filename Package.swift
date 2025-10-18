// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QuickOCRLLM",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "QuickOCRLLM", targets: ["QuickOCRLLM"])
    ],
    targets: [
        .executableTarget(
            name: "QuickOCRLLM",
            path: "Sources",
            resources: []
        )
    ]
)

