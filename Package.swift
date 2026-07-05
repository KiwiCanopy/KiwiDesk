// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KiwiDesk",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    // Linting runs as its own step (scripts/lint.sh: swift-format
    // + line/file-size checks), not a build-tool plugin. The
    // SwiftLint prebuild plugin cannot run during build planning on
    // the CI toolchain ("a prebuild command cannot use executables
    // built from source"), and its rules were advisory only.
    targets: [
        // Vendored Lua 5.4 (unmodified upstream C sources).
        .target(
            name: "CLua",
            path: "Vendor/CLua",
            sources: ["src"],
            publicHeadersPath: "include",
            cSettings: [
                .define("LUA_USE_MACOSX")
            ]
        ),
        // Core: state tracking, event loop, OS bridging.
        // Strictly separated from the GUI (see AGENTS.md).
        .target(
            name: "KiwiDeskCore",
            dependencies: ["CLua"],
            path: "Sources/KiwiDeskCore"
        ),
        // Executable: AppDelegate, menu bar, SwiftUI GUI.
        .executableTarget(
            name: "KiwiDesk",
            dependencies: ["KiwiDeskCore"],
            path: "Sources/KiwiDesk"
        ),
        .testTarget(
            name: "KiwiDeskCoreTests",
            dependencies: ["KiwiDeskCore"],
            path: "Tests/KiwiDeskCoreTests"
        ),
    ]
)
