import Foundation
import Testing

/// Every bar text field is placed through a named door (#1707): a
/// field whose line box is centred by hand looks right in the
/// system font — its ascent and descent nearly balance its caps —
/// and wrong in a tall face, so a behavioural suite that renders
/// the sites it knows cannot see a new one. The census counts each
/// text-field construction in `Sources/KiwiDeskCore/Bar`, per file,
/// against a register naming the door its placement takes and the
/// file that spells it, or the reason it takes none. The register
/// is the one copy of who is exempt.
///
/// Blind spot, stated: the door clause asks that the door is
/// spelled in the named file, not that every field of that file
/// reaches it, so a second field added beside one that does is
/// review's — the count moving is what brings it there.
@Suite("Bar text field census")
struct BarTextFieldCensusTests {
    static let root = "Sources/KiwiDeskCore/Bar"
    /// Every constructor spelling, not only `labelWithString:`
    /// (guard-prover): the trade is that a type reference written
    /// as a call counts too, while a subclass stays invisible.
    static let needle = "NSTextField("

    struct Entry {
        let count: Int
        /// The door's spelling, and the file under `root` that
        /// must spell it; nil where the reason says why none.
        let door: (needle: String, file: String)?
        let reason: String
    }

    static let register: [String: Entry] = [
        "AppBarItemView.swift": Entry(
            count: 3,
            door: ("BarTextGlyph.originY(", "AppBarItemView+Layout.swift"),
            reason: "title (originY), App Font glyph (an icon, "
                + "anchored by Metrics), badge (IndicatorBarBadgeCell)"
        ),
        "AppBarOverlay+Sizing.swift": Entry(
            count: 1,
            door: nil,
            reason: "measures a width, draws nothing"
        ),
        "ShelfCountView.swift": Entry(
            count: 1,
            door: ("BarTextGlyph.originY(", "ShelfCountView.swift"),
            reason: "the overflow count's number"
        ),
        "SpaceBarItemView.swift": Entry(
            count: 2,
            door: ("BarTextGlyph.frame(", "SpaceBarItemView+Layout.swift"),
            reason: "identifier (frame), badges (IndicatorBarBadgeCell)"
        ),
        "SpaceBarItemView+AppViews.swift": Entry(
            count: 1,
            door: ("BarTextGlyph.frame(", "SpaceBarItemView+Layout.swift"),
            reason: "App Font app glyphs (frame), minted per slot (#1942)"
        ),
        "SpaceBarOverlay+FrontApp.swift": Entry(
            count: 1,
            door: nil,
            reason: "measures the front-app title's width (#1856), "
                + "draws nothing"
        ),
        "SpaceBarOverlay.swift": Entry(
            count: 2,
            door: ("BarTextGlyph.originY(", "SpaceBarOverlay+FrontApp.swift"),
            reason: "front-app glyph (frame) and name (originY)"
        ),
    ]

    /// Where the badge cell sets its line, and the two sites that
    /// build a badge on it — the App Bar's builds its own field,
    /// so no render clause reaches it.
    static let badgeDoors = [
        (needle: "BarTextGlyph.lineTop(", file: "IndicatorBarBadgeCell.swift"),
        (needle: "IndicatorBarBadgeCell(", file: "AppBarItemView.swift"),
        (needle: "IndicatorBarBadgeCell(", file: "SpaceBarItemView.swift"),
    ]

    static func sources() throws -> [String: String] {
        let base = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(root)
        let files = try SourceScan.swiftSources(under: base)
        #expect(!files.isEmpty, "\(root) moved")
        var out: [String: String] = [:]
        for file in files {
            out[file.lastPathComponent] =
                try SourceScan.strippedSource(at: file)
        }
        return out
    }

    @Test("every bar text field is in the register")
    func everyFieldIsRegistered() throws {
        let sources = try Self.sources()
        var seen: [String: Int] = [:]
        for (name, text) in sources {
            let count = text.occurrences(of: Self.needle)
            if count > 0 { seen[name] = count }
        }
        #expect(!seen.isEmpty, "the needle matched nothing")
        for (name, count) in seen {
            let allowed = Self.register[name]?.count ?? 0
            #expect(
                count == allowed,
                """
                \(name) builds \(count) text field(s), \(allowed) \
                registered — place bar text through BarTextGlyph \
                and register the door (#1707)
                """
            )
        }
        for name in Self.register.keys where seen[name] == nil {
            Issue.record("\(name) is registered but builds none")
        }
    }

    @Test("each registered door is spelled where it is named")
    func doorsAreSpelled() throws {
        let sources = try Self.sources()
        let doors =
            Self.register.values.compactMap(\.door) + Self.badgeDoors
        for door in doors {
            let text = try #require(sources[door.file], "\(door.file)")
            #expect(
                text.contains(door.needle),
                "\(door.file) no longer reaches \(door.needle)"
            )
        }
    }

    /// Single-line mode draws a tall face above its own ascent,
    /// clipping it, whatever the frame (#1707).
    @Test("no bar text field sets single-line mode")
    func noSingleLineMode() throws {
        for (name, text) in try Self.sources() {
            #expect(
                !text.contains("usesSingleLineMode"),
                "\(name) sets usesSingleLineMode"
            )
        }
    }
}
