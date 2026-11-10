import Foundation
import Testing

/// A reader of a screen's bar or Pocket visibility in Core asks the
/// one `KiwiCore.shelfSettings(on:)` door (#3151), so a tiling-off
/// Space whose tick hides the bars reads them Hidden everywhere. The
/// scan looks for the bypass rather than counting the door's callers:
/// a visibility reader reached through `tiler.settings` or the
/// edge-only `settings(on:)`, directly or through a `let` bound to
/// either. Its residue: a binding handed on as an argument or kept in
/// a property is outside it, and is review's.
@Suite("Tiling off bars hidden seam (#3151)")
struct TilingOffBarsHiddenSeamTests {
    /// The visibility readers a bypass would reach.
    private static let readers = [
        "barVisibilities(", "drawsAtRest(", "revealActionLive(",
        "autoReadsAlways(", "pocketRest(", "pocketReservation(",
        "pocketRests", "appBarVisibility(", "shelfEdges(",
    ]

    /// File basename → why it reads a visibility beside the door.
    private static let allowed: [String: String] = [
        // The layout reservations: per mode, and nothing tiles on a
        // tiling-off Space, so its Hidden bars change no bounds.
        "KiwiCore+ScreenEdges.swift": "layout reservations",
        // The app-wide Pocket Show the per-screen door narrows.
        "KiwiCore+PocketPlate.swift": "the Pocket's own Show",
    ]

    /// The receivers that bypass the door in `source` (whitespace
    /// stripped): `tiler.settings`, `settings(on:…)`, and each `let`
    /// bound to either.
    private static func receivers(in source: String) -> [String] {
        let raw = [#"tiler\.settings"#, #"settings\(on:[^)]*\)"#]
        let pattern =
            #"let(\w+)=(?:tiler\.settings|settings\(on:[^)]*\))"#
            + #"(?![.\w])"#
        guard let binding = try? NSRegularExpression(pattern: pattern)
        else { return raw }
        let range = NSRange(source.startIndex..., in: source)
        let names = binding.matches(in: source, range: range).compactMap {
            Range($0.range(at: 1), in: source).map { source[$0] }
        }
        return raw + names.map { #"(?<![\w.])"# + $0 }
    }

    @Test("no Core reader of bar visibility bypasses the door")
    func readersTakeTheDoor() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
        let files = try SourceScan.swiftSources(under: root)
        #expect(files.count > 100)
        var found: Set<String> = []
        for file in files {
            let source = try SourceScan.strippedSource(at: file)
                .filter { !$0.isWhitespace }
            let receivers = Self.receivers(in: source)
            let bypass = Self.readers.contains { reader in
                let call = NSRegularExpression.escapedPattern(for: reader)
                return receivers.contains {
                    source.range(
                        of: $0 + #"\."# + call,
                        options: .regularExpression
                    ) != nil
                }
            }
            if bypass { found.insert(file.lastPathComponent) }
        }
        #expect(found == Set(Self.allowed.keys), "\(found)")
    }
}
