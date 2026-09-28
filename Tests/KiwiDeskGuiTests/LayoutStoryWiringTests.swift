import Foundation
import Testing

@testable import KiwiDesk

/// Where a layout thumbnail may play its story (#1750). Only a
/// surface that is READ rather than compared hosts one — the
/// Layouts chooser, its detail panel and the Home cards stay at
/// rest, since they restage as feedback on a changing draft and a
/// playing tile there would pull the eye to whichever one moves
/// (`docs/design-decisions.md` ▸ *A thumbnail that is read
/// rather than compared*).
@Suite("Layout story wiring (#1750)")
struct LayoutStoryWiringTests {
    /// The one copy of who may host a playing thumbnail, each
    /// with its reason.
    static let hosts: [String: String] = [
        "Onboarding/OnboardingSpaceRow.swift":
            "the tour's Spaces step, read once",
        "Settings/Components/Profiles/PresetPreviewSheet.swift":
            "a read-only preset preview; nothing in it is edited",
    ]

    /// Comments stripped, whitespace squashed, and `X.init(`
    /// spelled `X(`, so a call scan cannot be passed by the
    /// explicit initializer spelling.
    private func squashed(_ url: URL) throws -> String {
        SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
        .replacingOccurrences(of: ".init(", with: "(")
    }

    private func relative(_ url: URL) -> String {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk").path
        return String(url.path.dropFirst(root.count + 1))
    }

    /// Every Swift file of the GUI target: these are negative
    /// guards over "anywhere", so a compared surface in a tree
    /// no chrome scan lists is watched too.
    private func sources() throws -> [URL] {
        let files = try SourceScan.swiftSources(
            under: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent("Sources/KiwiDesk")
        )
        #expect(files.count > 50)
        return files
    }

    private func callers(of needle: String) throws -> Set<String> {
        var found: Set<String> = []
        for url in try sources() where try squashed(url).contains(needle) {
            found.insert(relative(url))
        }
        return found
    }

    @Test("only a read-only surface hosts a playing thumbnail")
    func hostsAreRuled() throws {
        #expect(
            try callers(of: "LayoutStoryThumbnail(")
                == Set(Self.hosts.keys)
        )
    }

    private static let player =
        "Settings/Components/Layouts/LayoutStoryThumbnail.swift"

    /// Every `call`'s argument list in `source`, so a needle
    /// asks what each call was HANDED.
    private func schematicCalls(
        in source: String,
        of call: String = "LayoutSchematicView("
    ) -> [String] {
        let text = Array(source)
        let needle = Array(call)
        var calls: [String] = []
        var i = 0
        while i + needle.count <= text.count {
            guard Array(text[i..<(i + needle.count)]) == needle else {
                i += 1
                continue
            }
            var cursor = i + needle.count - 1
            if let args = SourceScan.balanced(
                text,
                from: &cursor,
                open: "(",
                close: ")"
            ) {
                calls.append(args)
            }
            i += needle.count
        }
        return calls
    }

    /// A story phase reaches a schematic only through the player:
    /// no other `LayoutSchematicView(` call is handed a `motion:`
    /// in any spelling, so a compared surface cannot draw a frame
    /// that is not its rest.
    @Test("only the player hands a schematic a story phase")
    func motionComesFromThePlayer() throws {
        var handed: Set<String> = []
        var calls = 0
        for url in try sources() {
            for args in schematicCalls(in: try squashed(url)) {
                calls += 1
                if args.contains("motion:") {
                    handed.insert(relative(url))
                }
            }
        }
        // Non-empty first: the player and the four compared
        // surfaces each make one.
        #expect(calls >= 5)
        #expect(handed == [Self.player])
    }

    /// Beneath the view, each schematic takes its phase input
    /// from `LayoutSchematicView` alone, so no surface can build
    /// a schematic directly and hand it a moving frame.
    @Test("only the shared view hands a schematic its phase input")
    func phaseInputsComeFromTheView() throws {
        let inputs = [
            ("ScrollingSchematic(", "focusStep:"),
            ("MonocleSchematic(", "turn:"),
            ("FloatingSchematic(", "drag:"),
        ]
        for (call, label) in inputs {
            var handed: Set<String> = []
            for url in try sources() {
                let calls = schematicCalls(in: try squashed(url), of: call)
                if calls.contains(where: { $0.contains(label) }) {
                    handed.insert(relative(url))
                }
            }
            #expect(
                handed == [
                    "Settings/Components/Layouts/LayoutSchematicView.swift"
                ],
                "\(call) \(label)"
            )
        }
    }

    /// The story pace reaches the schematics only from the
    /// player: an ancestor of a compared surface writing the
    /// restage value would re-pace every schematic under it.
    @Test("only the player writes the restage pace")
    func restageComesFromThePlayer() throws {
        // Any spelling that is not a schematic's own read — an
        // `.environment(`, a `.transformEnvironment(`, a key path
        // handed elsewhere — marks a writer, and only the player
        // and the keys' declaration may carry one. The story flag
        // is held the same way: set anywhere else it would strip
        // a chooser's `+` and clip it.
        let keys = [
            ("schematicRestage", 7),
            ("schematicTellsStory", 1),
        ]
        for (key, floor) in keys {
            let read = "@Environment(\\.\(key))"
            var writers: Set<String> = []
            var readers = 0
            for url in try sources() {
                let source = try squashed(url)
                readers += source.components(separatedBy: read).count - 1
                let rest = source.replacingOccurrences(of: read, with: "")
                if rest.contains(key) {
                    writers.insert(relative(url))
                }
            }
            #expect(readers >= floor, "\(key)")
            #expect(
                writers == [
                    Self.player,
                    "Settings/Components/Layouts/SchematicMotion.swift",
                ],
                "\(key)"
            )
        }
    }

    /// The engine canvas draws only through the player, and clips
    /// at its screen edge, where a pile hangs past on a real
    /// screen too.
    @Test("only the player draws the story canvas, which clips")
    func canvasComesFromThePlayer() throws {
        #expect(try callers(of: "LayoutStoryCanvas(") == [Self.player])
        let root = SourceScan.repoRoot(from: #filePath)
        let canvas = try squashed(
            root.appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Layouts/"
                    + "LayoutStoryCanvas.swift"
            )
        )
        // The clip sits on the whole drawn screen, not a tile.
        #expect(canvas.contains("tiles(in:geo.size)}.clipped()"))
        #expect(canvas.components(separatedBy: ".clipped()").count == 2)
        // Windows keep their identity across counts only while the
        // canvas keys them by id, never by position.
        #expect(canvas.contains("ForEach(space.windows,id:\\.raw)"))
    }

    /// The tour mounts the playing row, lazily, so a row below
    /// the fold plays when it scrolls in rather than unseen.
    @Test("the tour mounts the playing rows lazily")
    func tourMountsRows() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let spaces = try squashed(
            root.appendingPathComponent(
                "Sources/KiwiDesk/Onboarding/OnboardingView+Spaces.swift"
            )
        )
        #expect(spaces.contains("LazyVStack("))
        #expect(spaces.contains("OnboardingSpaceRow("))
        #expect(!spaces.contains("LayoutSchematicView("))
    }

    /// Under Reduce Motion the player never leaves its rest
    /// frame: the guard precedes the jump to the start frame,
    /// which no animation gate can stand in for.
    @Test("Reduce Motion never leaves the rest frame")
    func reduceMotionStaysAtRest() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let player = try squashed(
            root.appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Layouts/"
                    + "LayoutStoryThumbnail.swift"
            )
        )
        let guardAt = try #require(
            player.range(of: "guard!reduceMotion,story.playselse")
        )
        let jump = try #require(player.range(of: "atStart=true"))
        #expect(guardAt.upperBound < jump.lowerBound)
        // One jump, one suppression: a second path to the start
        // frame would sit outside the guard's reach.
        #expect(player.components(separatedBy: "atStart=true").count == 2)
        #expect(
            player.components(separatedBy: "withTransaction(").count == 2
        )
        // And what the player DRAWS is the story's frame: a
        // literal count or motion in its call kills the beat.
        let calls = schematicCalls(in: player)
        #expect(calls.count == 1)
        #expect(calls.first?.contains("windows:frame.windows") == true)
        #expect(calls.first?.contains("motion:frame.motion") == true)
        // A tiling story draws the canvas at the story's count.
        let canvases = schematicCalls(in: player, of: "LayoutStoryCanvas(")
        #expect(canvases.count == 1)
        #expect(canvases.first?.contains("count:frame.windows,") == true)
        #expect(calls.first?.contains("windows:frame.windows,") == true)
        // The frame is the story's phase: start while playing.
        #expect(
            player.contains("letframe=atStart?story.start:story.rest")
        )
    }
}
