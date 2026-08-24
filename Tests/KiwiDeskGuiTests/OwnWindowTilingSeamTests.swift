import Foundation
import Testing

/// The Settings window is the ONE own window that tiles
/// (#678 item 18): `EventLoop.shouldForceFloat` exempts an own
/// window from force-floating only when it carries
/// `OwnWindowTiling.identifier`, and the GUI stamps that mark in
/// exactly one place. The chrome that must stay unmarked — the
/// onboarding tour and the Config Issues window — is chrome
/// precisely because it ends; stamping the mark onto one of
/// them would hand a completion-condition surface a layout
/// slot. `OwnWindowTiling`'s doc carries the argument.
///
/// Both needles are scanned: the constant's name, and its raw
/// value — a hand-copied `"kiwidesk.tiles"` literal would stamp
/// the mark while bypassing a constant-name scan entirely.
///
/// Disclosed limit: `SourceScan.stripComments` cuts each line at
/// its first `//`, even inside a string literal, so a
/// `//`-bearing literal ahead of a needle on the same line
/// erases that hit. Fail-open, and the same limit the sibling
/// seam guards carry.
@Suite("Own-window tiling seam")
struct OwnWindowTilingSeamTests {
    private let needles = [
        "OwnWindowTiling",
        "kiwidesk.tiles",
    ]

    /// File path (repo-relative) -> how many times it may name
    /// the mark. **This map is the one copy of who may stamp
    /// it**: the Settings window controller, once, at window
    /// construction — plus the declaration itself and the one
    /// place the engine reads it back.
    private let allowed = [
        "Sources/KiwiDesk/Settings/SettingsWindowController.swift":
            1,
        // The constant's own file: the name and the literal, so
        // two hits.
        "Sources/KiwiDeskCore/Events/OwnWindowTiling.swift": 2,
        // The read side — `shouldForceFloat`'s own-window arm.
        "Sources/KiwiDeskCore/Events/EventLoop+WindowPolicy.swift":
            1,
        // The second read side (#935): the dialog classifier
        // exempts the marked window from the close-return raise
        // stand-down — a read of the mark, never a stamp.
        "Sources/KiwiDeskCore/Events/EventLoop+RaiseStandDown.swift":
            1,
        // The third read side (#953): the local press monitor
        // records a press only when it landed in the marked
        // window, so a click on the bars, the tour or a panel
        // cannot overwrite the press the gesture classifiers
        // read. A read of the mark, never a stamp.
        "Sources/KiwiDeskCore/Events/MouseTracker.swift": 1,
    ]

    /// BOTH source trees: Core builds its own `NSWindow`s (the
    /// bars, the border overlays), so a stamp added there would
    /// be invisible to a GUI-only scan — and the claim the map
    /// makes is about the whole app, not one target.
    private static var scanRoots: [URL] {
        let sources = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources")
        return ["KiwiDesk", "KiwiDeskCore"].map {
            sources.appendingPathComponent($0)
        }
    }

    /// A root that reads nothing scans nothing, and a scan over
    /// no files agrees with any map it is compared against — so
    /// a renamed or moved tree reds here rather than going
    /// quiet (the sibling lenses' root-coverage check).
    @Test("Every scan root is actually read")
    func everyRootIsRead() throws {
        for root in Self.scanRoots {
            #expect(
                !(try SourceScan.swiftSources(under: root))
                    .isEmpty,
                Comment(
                    rawValue:
                        "\(root.lastPathComponent) yielded no "
                        + "Swift files — this seam no longer "
                        + "covers that tree"
                )
            )
        }
        // A target added under `Sources/` joins the roster
        // above; this is what makes dropping one visible.
        #expect(Self.scanRoots.count == 2)
    }

    @Test("Only the Settings window carries the tiling mark")
    func markStaysWhereItBelongs() throws {
        let prefix =
            SourceScan.repoRoot(from: #filePath).path
            + "/"
        let trees = Self.scanRoots

        var counts: [String: Int] = [:]
        for tree in trees {
            for file in try SourceScan.swiftSources(under: tree) {
                let source = SourceScan.stripComments(
                    try String(contentsOf: file, encoding: .utf8)
                )
                // Summed, never maxed: a second stamp added
                // beside a first is exactly what this counts,
                // and a max would absorb it silently.
                let hits = needles.reduce(0) {
                    $0 + source.occurrences(of: $1)
                }
                guard hits > 0 else { continue }
                let key =
                    file.path.hasPrefix(prefix)
                    ? String(file.path.dropFirst(prefix.count))
                    : file.path
                counts[key] = hits
            }
        }

        // Asserted as a whole map rather than per-file, so a NEW
        // file naming the mark fails just as loudly as an
        // existing one gaining a second stamp.
        #expect(counts == allowed)
    }
}
