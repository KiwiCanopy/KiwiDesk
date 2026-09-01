import Foundation
import Testing

@testable import KiwiDesk

/// #991's own condition on its fix: the input-source reading
/// "becomes one seam consulted by every focus-destination site,
/// not a per-site condition, or the next site will forget it".
///
/// That is two claims about SHAPE, and this suite holds both.
/// Neither can say a ring stopped being drawn — only a device
/// with keyboard navigation ON does that — but a second reader
/// appearing beside a view is exactly how the one seam stops
/// being one, and nothing else in the tree would notice.
@Suite("Settings input source is one seam (#991)")
struct SettingsInputSourceSeamTests {
    /// Reach, stated: the scan covers the Settings tree only.
    /// `StatusItemController+Menu.swift` reads the same property
    /// outside it and is not in scope — it is a menu-bar
    /// behaviour, not a focus destination, and folding it in
    /// would make this suite's subject two different things.
    /// TWO readers, and the pair is the ruling rather than an
    /// oversight (`architect-reviewer`, 2026-09-01). They ask
    /// different questions of the same property:
    ///
    /// - `SettingsInputSource` — would the platform have moved
    ///   focus for this NAVIGATION? Refuses a mouse event.
    /// - `ClickBornFocus` — did the mouse cause this FOCUS
    ///   CHANGE on a `.focusable()` control? Also weighs the
    ///   button state, which the first must not, because a
    ///   navigation may be programmatic while a button is down.
    ///
    /// Merging them would refuse programmatic focus, which the
    /// second must allow. A THIRD entry is the thing to refuse:
    /// it would mean a view answering the question beside itself
    /// again, which is what #991 removed.
    @Test("only the two seams read what macOS is dispatching")
    func oneReaderOfTheCurrentEvent() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
        let files = try SourceScan.swiftSources(under: root)
        // A scan that read nothing would pass having looked at
        // nothing (#635).
        #expect(files.count > 50)
        var readers: [String] = []
        for file in files {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            .split(whereSeparator: \.isWhitespace)
            .joined()
            // `currentEvent` bare, not `NSApp.currentEvent`:
            // the receiver has more than one spelling — `NSApp?`
            // for nil-safety, `NSApplication.shared` — and a
            // needle pinned to one of them read EMPTY the moment
            // the seam gained its `?`, which is this suite's own
            // near-miss (2026-09-01). The question is who reads
            // the current event at all, not how they spell the
            // receiver.
            if source.contains("currentEvent") {
                readers.append(file.lastPathComponent)
            }
        }
        #expect(
            readers.sorted() == [
                "ClickBornFocus.swift", "SettingsInputSource.swift",
            ],
            Comment(
                rawValue:
                    "the current event is read in "
                    + "\(readers.sorted()) — it has exactly two "
                    + "homes, one per question (see this test's "
                    + "docstring). A reader beside a VIEW is the "
                    + "per-site condition #991 refused; route it "
                    + "through whichever of the two it is asking."
            )
        )
    }

    /// The other half: a seam nothing consults is not a seam. If
    /// a future edit drops the gate from both focus statements,
    /// the needle above still passes — the seam would simply sit
    /// there unread.
    @Test("both focus statements consult the recorded source")
    func bothStatementsConsultTheSeam() throws {
        let expected = [
            "SettingsView.swift": "the arrival raise",
            "HomeScreen.swift": "the return restore",
        ]
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
        let files = try SourceScan.swiftSources(under: root)
        for (name, which) in expected {
            let file = try #require(
                files.first { $0.lastPathComponent == name },
                "\(name) is gone"
            )
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            .split(whereSeparator: \.isWhitespace)
            .joined()
            #expect(
                source.contains("nav.navigationMovesFocus"),
                Comment(
                    rawValue:
                        "\(name) states a focus destination "
                        + "without consulting the input source — "
                        + "\(which) then fires on a mouse "
                        + "navigation and draws a ring macOS "
                        + "would not have drawn (#991)"
                )
            )
        }
    }
}
