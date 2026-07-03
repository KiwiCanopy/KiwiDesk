// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KiwiDesk",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        // Prebuilt SwiftLint binary plugin (no source build).
        .package(
            url: "https://github.com/SimplyDanny/SwiftLintPlugins",
            from: "0.57.0"
        )
    ],
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
            path: "Sources/KiwiDeskCore",
            plugins: [lintPlugin]
        ),
        // Executable: AppDelegate, menu bar, SwiftUI GUI.
        .executableTarget(
            name: "KiwiDesk",
            dependencies: ["KiwiDeskCore"],
            path: "Sources/KiwiDesk",
            plugins: [lintPlugin]
        ),
        .testTarget(
            name: "KiwiDeskCoreTests",
            dependencies: ["KiwiDeskCore"],
            path: "Tests/KiwiDeskCoreTests"
        ),
    ]
)

var lintPlugin: Target.PluginUsage {
    .plugin(
        name: "SwiftLintBuildToolPlugin",
        package: "SwiftLintPlugins"
    )
}
