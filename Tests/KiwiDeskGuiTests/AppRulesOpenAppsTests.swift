import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// App Rules' Space and Float pickers lead with the open apps (#2297),
/// one without a bundle id named by its process name, which a rule
/// matches (#3211), never the windows beneath the normal layer; the
/// Tile picker keeps its guessed list (#2071).
@Suite("App Rules ▸ Open apps (#2297)")
@MainActor
struct AppRulesOpenAppsTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDesk/Settings")

    private func source(_ path: String) throws -> String {
        try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(path)
        )
    }

    @Test("a bundle-less app is offered, keyed by its name (#3211)")
    func bundleLessIsOffered() {
        let app = OpenApp(
            app: AppRef(bundleID: nil, name: "QEMU-System-AArch64"),
            name: "qemu-system-aarch64"
        )
        let lists = AppPickerSections.lists(
            openApps: [app],
            installed: [],
            exclude: [],
            query: ""
        )
        #expect(lists.openApps.map(\.key) == ["qemu-system-aarch64"])
    }

    @Test("a bundle-less app's rule previews its open windows (#3211)")
    func previewListsBundleLessWindows() {
        let model = makeTestModel()
        model.core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(9),
                    pid: 900_401,
                    appName: "qemu-system-aarch64",
                    appBundleID: nil,
                    title: "Android Emulator - kc-api37:5554"
                )
            )
        )
        let preview = AppRuleMatchPreview(
            model: model,
            app: "qemu-system-aarch64"
        )
        #expect(
            preview.windows.map(\.title)
                == ["Android Emulator - kc-api37:5554"]
        )
    }

    @Test("Space and Float take the section, Tile does not")
    func wiring() throws {
        let needle = "openAppsOf: model.core"
        let lists = try source("Sections/AppRulesSection+Lists.swift")
        #expect(lists.occurrences(of: needle) == 2)
        let tile = try source("Sections/AppRulesSection+Automatic.swift")
        #expect(tile.occurrences(of: "openAppsOf:") == 0)
        let selector = try source(
            "Components/Common/AppRuleControls.swift"
        )
        #expect(
            selector.occurrences(
                of: "{ core.openApps(beneathNormal: false) }"
            ) == 1
        )
    }
}
