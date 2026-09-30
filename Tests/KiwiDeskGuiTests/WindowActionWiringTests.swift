import Foundation
import Testing

/// The window actions' wirings no behaviour test can see (#1518).
/// `BarWindowActionRowsTests` asserts the refusal's log line,
/// written before the pill, and records the activate and the
/// press in separate arrays, so a cue that stopped drawing, or an
/// activate moved after the press, leaves it green; and every
/// suite that presses injects its own seams, so both
/// `makeTestCore` twins losing their inert pins reds nothing.
@Suite("Window actions stay wired (#1518)")
struct WindowActionWiringTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    private static func stripped(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined()
    }

    /// The cue draws, through the one refusal-pill door, on the
    /// window `cueWindow(for:)` picked.
    @Test("a refused window action draws its pill")
    func cueDraws() throws {
        let body = Self.stripped(
            try SourceScan.functionBody(
                of: "cueWindowAction",
                in: "KiwiCore+WindowActions.swift",
                under: "Commands"
            )
        )
        #expect(body.contains("letwindow=cueWindow(for:target)"))
        #expect(body.occurrences(of: "flashRefusalPill(window,") == 1)
    }

    /// Activate, then press: the owner's ruling (2026-09-30), since
    /// some apps ignore a menu press while in the background.
    @Test("New Window activates the app before it presses")
    func activateBeforePress() throws {
        let body = try SourceScan.functionBody(
            of: "newWindow",
            in: "KiwiCore+WindowActions.swift",
            under: "Commands"
        )
        let activate = try #require(
            body.range(of: "openOrFocus.activate(")
        )
        let press = try #require(
            body.range(of: "windowActions.newWindow(")
        )
        #expect(activate.lowerBound < press.lowerBound)
    }

    /// Both twins keep the three pins: without them a suite that
    /// runs `new_window` activates and walks a real app.
    @Test("both test cores pin the window actions inert")
    func testCoresPin() throws {
        for target in ["KiwiDeskCoreTests", "KiwiDeskGuiTests"] {
            let source = try String(
                contentsOf: Self.root.appendingPathComponent(
                    "Tests/\(target)/TestCore.swift"
                ),
                encoding: .utf8
            )
            for pin in [
                "core.openOrFocus.activate = { _ in }",
                "core.windowActions.newWindow = { _, _ in }",
                "core.windowActions.close = { _, _ in }",
            ] {
                #expect(source.occurrences(of: pin) == 1, "\(target): \(pin)")
            }
        }
    }
}
