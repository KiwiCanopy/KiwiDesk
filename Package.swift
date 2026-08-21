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
    // Sparkle is the app's update channel
    // (docs/design-decisions.md ▸ "No distribution channel
    // without an update path"). It is the FIRST third-party
    // Swift dependency here — CLua below is vendored C — and it
    // is declared on the GUI executable alone, never on
    // KiwiDeskCore: Core must stay buildable and testable
    // without AppKit-adjacent vendor code (AGENTS.md §1).
    //
    // Upstream ships `Sparkle.framework` AD-HOC signed with no
    // Team ID (checked against 2.9.6, both distributions), so
    // there is no vendor signature to preserve and
    // scripts/build-app.sh signs the whole nest with our
    // Developer ID. See packaging-and-release.md.
    dependencies: [
        .package(
            url: "https://github.com/sparkle-project/Sparkle",
            from: "2.9.6"
        )
    ],
    targets: [
        // Vendored Lua 5.5 (unmodified upstream C sources).
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
        // `LocalizationManager` lives here (issue #9) so both
        // the SwiftUI GUI and the AppKit quick menu can call
        // it; the locale JSON files bundle with this target.
        // Read them through `Bundle.kiwiDeskCore`, never
        // `Bundle.module` — inside an `.app` the generated
        // accessor looks where codesign forbids and then traps
        // (#89, AGENTS.md §5).
        // Resources/Locales/en.json itself is a BUILD-TIME
        // translator manifest, not something the app reads at
        // runtime — English lives inline at every `L(key,
        // english)` call site, so there is intentionally no
        // `en` locale file to load (see `LocaleCatalog`'s
        // `!= "en"` filter). Don't "fix" that filter.
        .target(
            name: "KiwiDeskCore",
            dependencies: ["CLua"],
            path: "Sources/KiwiDeskCore",
            resources: [
                .copy("Resources/Locales"),
                // Vendored SketchyBar App Font (#294) —
                // refresh with scripts/update-app-font.sh,
                // never hand-edit (see AppFont/UPSTREAM.md).
                .copy("Resources/AppFont"),
                // Bundled color palettes (#375).
                .copy("Resources/Palettes"),
            ]
        ),
        // Executable: AppDelegate, menu bar, SwiftUI GUI.
        .executableTarget(
            name: "KiwiDesk",
            dependencies: [
                "KiwiDeskCore",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/KiwiDesk",
            // Pre-rasterized from the vector masters in
            // /assets (see assets/README.md) — plain files,
            // not an asset catalog: `swift build` (CI) does
            // not run actool.
            resources: [
                .copy("Resources/MenuBarIcon.tiff"),
                .copy("Resources/Wordmark.png"),
                .copy("Resources/WordmarkDark.png"),
                .copy("Resources/AppMark.png"),
            ]
        ),
        .testTarget(
            name: "KiwiDeskCoreTests",
            dependencies: ["KiwiDeskCore"],
            path: "Tests/KiwiDeskCoreTests"
        ),
        // GUI model tests (#64): SwiftPM ≥5.5 lets a test
        // target depend on an executable target, so the
        // dashboard's view-model state machine is testable
        // without splitting the GUI into a library.
        .testTarget(
            name: "KiwiDeskGuiTests",
            dependencies: ["KiwiDesk", "KiwiDeskCore"],
            path: "Tests/KiwiDeskGuiTests"
        ),
    ]
)
