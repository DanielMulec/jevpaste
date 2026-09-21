// swift-tools-version:5.9
// THROWAWAY probe for GitHub issue #11. Not production code. Do not depend on this.
import PackageDescription

let package = Package(
    name: "macos-probe",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MacOSProbe",
            path: "Sources/MacOSProbe"
        )
    ]
)
