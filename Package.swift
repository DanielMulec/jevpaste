// swift-tools-version:6.0
// jevpaste — one Swift package built with the Command Line Tools only (ADR 0001).
// Module boundaries follow "Choose native module boundaries and local quality checks":
// SmartPasteCore owns the seams and depends on nothing; adapters depend on Core; the app depends on all.
import PackageDescription

let testingDependency: Target.Dependency = .product(name: "Testing", package: "swift-testing")

let package = Package(
    name: "jevpaste",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "JevPasteApp", targets: ["JevPasteApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-testing.git", exact: "6.3.2")
    ],
    targets: [
        .target(name: "SmartPasteCore"),
        .target(name: "JevGateway", dependencies: ["SmartPasteCore"]),
        .target(name: "HistoryStore", dependencies: ["SmartPasteCore"]),
        .target(name: "MacInterop", dependencies: ["SmartPasteCore"]),
        .executableTarget(
            name: "JevPasteApp",
            dependencies: ["SmartPasteCore", "JevGateway", "HistoryStore", "MacInterop"]
        ),
        // Fixtures: synthetic spike data for the Narrowing tests (`scripts/extract-narrowing-fixtures.py`).
        .testTarget(
            name: "SmartPasteCoreTests", dependencies: ["SmartPasteCore", testingDependency],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "JevGatewayTests", dependencies: ["JevGateway", "SmartPasteCore", testingDependency],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(name: "HistoryStoreTests", dependencies: ["HistoryStore", "SmartPasteCore", testingDependency]),
        .testTarget(name: "MacInteropTests", dependencies: ["MacInterop", "SmartPasteCore", testingDependency]),
        .testTarget(
            name: "JevPasteAppTests", dependencies: ["JevPasteApp", "HistoryStore", "SmartPasteCore", testingDependency]
        ),
    ],
    swiftLanguageModes: [.v6]
)
