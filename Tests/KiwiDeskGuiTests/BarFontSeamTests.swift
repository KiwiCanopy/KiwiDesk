import Foundation
import Testing

/// Bar text takes its face from `BarFont` (#1681): a bar file
/// that builds a font of its own draws text the shelf's family and
/// weight never reach. The scan counts every spelling that makes a
/// face — the system calls and the by-name and by-descriptor
/// initializers — per file, keyed by its path under the repo,
/// against a map of the sites that may: the resolver, the App
/// Font and its fallbacks, which draw a glyph rather than text.
/// The map is the one copy of who is exempt; a new entry states
/// its reason.
@Suite("Bar text font seam")
struct BarFontSeamTests {
    static let roots = [
        "Sources/KiwiDeskCore/Bar",
        "Sources/KiwiDeskCore/Layouts",
    ]

    /// The spellings that make a face. None contains another.
    static let needles = [
        "systemFont(", "boldSystemFont(", "monospacedSystemFont(",
        "monospacedDigitSystemFont(", "labelFont(", "menuBarFont(",
        "userFont(", "NSFont(name:", "NSFont(descriptor:",
    ]

    static let bar = "Sources/KiwiDeskCore/Bar/"

    static let allowed: [String: (count: Int, reason: String)] = [
        bar + "BarFont.swift": (
            5, "the resolver: System's faces, the axis, the digits"
        ),
        bar + "BarFont+Faces.swift": (
            5, "the resolver: a family's faces and the system axes"
        ),
        bar + "AppFont.swift": (2, "the App Font itself"),
        bar + "AppBarItemView+GlyphSlot.swift": (
            2, "App Font glyph fallback"
        ),
        bar + "SpaceBarItemView+Style.swift": (
            1, "App Font glyph fallback"
        ),
        bar + "SpaceBarOverlay+FrontApp.swift": (
            1, "App Font glyph fallback"
        ),
        bar + "BarTextGlyph.swift": (
            1, "metrics of a field with no font"
        ),
    ]

    @Test("only the resolver and glyph fallbacks make a face")
    func onlyAllowedSitesMakeAFace() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let prefix = root.path + "/"
        var seen: [String: Int] = [:]
        for path in Self.roots {
            let files = try SourceScan.swiftSources(
                under: root.appendingPathComponent(path)
            )
            #expect(!files.isEmpty, "\(path) moved")
            for file in files {
                let text = try SourceScan.strippedSource(at: file)
                let count = Self.needles.reduce(0) {
                    $0 + text.occurrences(of: $1)
                }
                let relative = file.path.replacingOccurrences(
                    of: prefix,
                    with: ""
                )
                if count > 0 { seen[relative] = count }
            }
        }
        for (name, count) in seen {
            let allowed = Self.allowed[name]?.count ?? 0
            let message =
                "\(name) makes \(count) font(s), "
                + "\(allowed) allowed — bar text asks "
                + "KiwiShelf.textFont / badgeFont"
            #expect(count == allowed, "\(message)")
        }
        for name in Self.allowed.keys where seen[name] == nil {
            Issue.record("\(name) is allowed but makes no font")
        }
    }

    /// The font-set observer is wired in `start()` and retired in
    /// `stop()`, and a wiring retires the previous token first —
    /// deleting any of the three reds nothing at runtime.
    @Test("the font-set observer is wired, re-wired and retired")
    func fontSetObserverIsWired() throws {
        let core = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore/App")
        let source = try SourceScan.strippedSource(
            at: core.appendingPathComponent("KiwiCore+FontSet.swift")
        )
        let wiring = try #require(
            SourceScan.declarationBody(after: "func wireFontSet", in: source)
        )
        let retire = try #require(wiring.range(of: "retireFontSet()"))
        let observe = try #require(wiring.range(of: "addObserver("))
        #expect(
            retire.lowerBound < observe.lowerBound,
            "wireFontSet() no longer retires the old token first"
        )
        #expect(wiring.contains("fontSetDidChange()"))
        let handler = try #require(
            SourceScan.declarationBody(
                after: "func fontSetDidChange",
                in: source
            )
        )
        #expect(handler.contains("BarFont.invalidate()"))
        #expect(handler.contains("updateBars()"))
        let boot = try SourceScan.strippedSource(
            at: core.appendingPathComponent("KiwiCore+Boot.swift")
        )
        let start = try #require(
            SourceScan.declarationBody(after: "func start(", in: boot)
        )
        #expect(
            start.contains("wireFontSet()"),
            "start() no longer wires the font-set observer"
        )
        let lifecycle = try SourceScan.strippedSource(
            at: core.appendingPathComponent("KiwiCore+Lifecycle.swift")
        )
        let stop = try #require(
            SourceScan.declarationBody(after: "func stop(", in: lifecycle)
        )
        #expect(
            stop.contains("retireFontSet()"),
            "stop() no longer retires the font-set observer"
        )
    }
}
