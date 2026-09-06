import Foundation
import Testing

/// The Settings raise tells Core first (#1281). Every mouse and
/// chord path that opens Settings funnels into
/// `SettingsWindowController.show()`, and a bare `forceFront` of
/// a window the row just panned out reports a clickless focus
/// that #1161's placement distrust bounces for two seconds. The
/// raise branch therefore calls `KiwiCore.focusOwnWindow` BEFORE
/// `forceFront` — `PlacementIntentTests` holds what that door
/// does. What a fixture cannot see is the wiring: a `show()` that
/// dropped the call, or reordered it after the order-front, would
/// go dead with every unit test green.
@Suite("The Settings raise goes through the focus command (#1281)")
struct SettingsOpenFocusSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let gui = root.appendingPathComponent(
        "Sources/KiwiDesk"
    )
    private static let controller = gui.appendingPathComponent(
        "Settings/SettingsWindowController.swift"
    )

    /// File (name) -> how many times it may call the door.
    /// **This map is the one copy of who may**: the Settings
    /// window controller, once, in its raise branch. A second
    /// own window that tiles cannot exist while
    /// `OwnWindowTilingSeamTests` holds, so a second entry here
    /// is a deliberate edit, never a drift.
    private static let allowed = [
        "SettingsWindowController.swift": 1
    ]

    /// Pinned to the RAISE branch of `show()` — the balanced body
    /// that follows `if let window {` — so the first-open path,
    /// where no id exists yet, is not what satisfies it.
    @Test("show()'s raise branch tells Core before forceFront")
    func raiseBranchTellsCoreFirst() throws {
        let source = SourceScan.stripComments(
            try String(contentsOf: Self.controller, encoding: .utf8)
        )
        let show = try #require(
            SourceScan.declarationBody(
                after: "func show() {",
                in: source
            )
        )
        let branch = try #require(
            SourceScan.declarationBody(
                after: "if let window {",
                in: show
            )
        )
        let focus = try #require(
            branch.range(
                of: "focusOwnWindow(number: window.windowNumber)"
            )
        )
        let front = try #require(
            branch.range(of: "NSApp.forceFront(window)")
        )
        #expect(focus.upperBound <= front.lowerBound)
    }

    /// The door has the callers the map names, and the GUI never
    /// spells the focus VERB itself — the Space gate and the
    /// window-number bridge are Core's, beside the arm they
    /// mirror, so a GUI copy of either is the drift.
    @Test("the door's callers are the ruled ones, and the verb has none")
    func doorCallersAreRuled() throws {
        let doors = try SourceScan.identifierSites(
            of: "focusOwnWindow(",
            under: Self.gui
        )
        var found: [String: Int] = [:]
        for site in doors {
            found[site.file.lastPathComponent, default: 0] += 1
        }
        #expect(
            found == Self.allowed,
            "found \(doors.map(\.site).joined(separator: ", "))"
        )
        let verbs = try SourceScan.identifierSites(
            of: "focusWindow(",
            under: Self.gui
        )
        #expect(
            verbs.isEmpty,
            "found \(verbs.map(\.site).joined(separator: ", "))"
        )
    }
}
