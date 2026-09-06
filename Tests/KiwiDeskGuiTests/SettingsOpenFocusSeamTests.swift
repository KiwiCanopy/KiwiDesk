import CoreGraphics
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The Settings raise tells Core first (#1281). Every mouse and
/// chord path that opens Settings funnels into
/// `SettingsWindowController.show()`, and a bare `forceFront` of
/// a window the row just panned out reports a clickless focus
/// that #1161's placement distrust bounces for two seconds. The
/// raise branch therefore goes through `KiwiCore.focusWindow`
/// BEFORE `forceFront`, so the report arrives intended —
/// `PlacementIntentTests` holds the Core half. What a fixture
/// cannot see is the wiring: a `show()` that dropped the call, or
/// reordered it after the order-front, would go dead with every
/// unit test green.
@Suite("The Settings raise goes through the focus command (#1281)")
struct SettingsOpenFocusSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let gui = root.appendingPathComponent(
        "Sources/KiwiDesk"
    )
    private static let controller = gui.appendingPathComponent(
        "Settings/SettingsWindowController.swift"
    )

    private static func source() throws -> String {
        SourceScan.stripComments(
            try String(contentsOf: controller, encoding: .utf8)
        )
    }

    /// Pinned to the RAISE branch of `show()` — the balanced body
    /// that follows `if let window {` — so the first-open path,
    /// where no id exists yet, is not what satisfies it.
    @Test("show()'s raise branch tells Core before forceFront")
    func raiseBranchTellsCoreFirst() throws {
        let show = try #require(
            SourceScan.declarationBody(
                after: "func show() {",
                in: try Self.source()
            )
        )
        let branch = try #require(
            SourceScan.declarationBody(
                after: "if let window {",
                in: show
            )
        )
        let focus = try #require(
            branch.range(of: "focusThroughCore(window)")
        )
        let front = try #require(
            branch.range(of: "NSApp.forceFront(window)")
        )
        #expect(focus.upperBound <= front.lowerBound)
    }

    /// The GUI tree issues the focus command from ONE site, the
    /// helper, and that helper consults the predicate rather than
    /// handing Core every window number it is given.
    @Test("the GUI's one focusWindow call sits behind the predicate")
    func focusCommandHasOneGuiCaller() throws {
        let sites = try SourceScan.identifierSites(
            of: "focusWindow(",
            under: Self.gui
        )
        #expect(
            sites.count == 1
                && sites.first?.file.lastPathComponent
                    == "SettingsWindowController.swift",
            "found \(sites.map(\.site).joined(separator: ", "))"
        )
        let helper = try #require(
            SourceScan.declarationBody(
                after: "func focusThroughCore(",
                in: try Self.source()
            )
        )
        #expect(helper.contains("coreFocusTarget("))
        #expect(helper.contains("focusWindow("))
    }

    /// The predicate names a tracked window on the ACTIVE Space
    /// and nothing else: a window on another Space is reached by
    /// its clickless report, an untracked number is not Core's,
    /// and AppKit reports a window without a device as `<= 0`.
    @Test("the predicate names a tracked window on the active Space")
    @MainActor
    func predicateNamesTrackedActiveWindow() {
        let core = makeTestCore()
        for id in 1...2 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: pid_t(id),
                        appName: "App\(id)",
                        frame: CGRect(
                            x: 0,
                            y: 0,
                            width: 400,
                            height: 300
                        )
                    )
                )
            )
        }
        let active = core.state.workspaces.activeSpace
        #expect(active != nil)
        // Window 2 leaves the active Space.
        core.state.workspaces.focus(WindowID(2), in: active!)
        _ = core.execute("move_to_space", args: [.string("2")])
        #expect(
            core.state.workspaces.space(of: WindowID(2)) != active
        )
        let target = { (number: Int) -> WindowID? in
            SettingsWindowController.coreFocusTarget(
                windowNumber: number,
                core: core
            )
        }
        #expect(target(1) == WindowID(1))
        #expect(target(2) == nil)
        #expect(target(7) == nil)
        #expect(target(0) == nil)
        #expect(target(-1) == nil)
    }
}
