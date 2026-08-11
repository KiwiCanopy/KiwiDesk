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
    /// construction.
    private let allowed = [
        "Sources/KiwiDesk/Settings/SettingsWindowController.swift":
            1
    ]

    @Test("Only the Settings window carries the tiling mark")
    func markStaysWhereItBelongs() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let gui =
            root
            .appendingPathComponent("Sources")
            .appendingPathComponent("KiwiDesk")
        let prefix = root.path + "/"

        var counts: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: gui) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            // One use site may match both needles (the constant
            // resolves to the literal only in Core), so count
            // the maximum, not the sum — a file naming either
            // needle is a stamping site.
            let hits =
                needles.map {
                    source.occurrences(of: $0)
                }.max() ?? 0
            guard hits > 0 else { continue }
            let key =
                file.path.hasPrefix(prefix)
                ? String(file.path.dropFirst(prefix.count))
                : file.path
            counts[key] = hits
        }

        // Asserted as a whole map rather than per-file, so a NEW
        // file naming the mark fails just as loudly as an
        // existing one gaining a second stamp.
        #expect(counts == allowed)
    }
}
