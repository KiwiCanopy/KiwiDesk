import Foundation
import Testing

@testable import KiwiDeskCore

/// One width and one corner style for every window stroke — the
/// focus ring, the drag ghost and the drop zone (#1742, owner
/// ruling 2026-09-28): derived from the border, stored once.
@Suite("Window stroke")
struct WindowStrokeTests {
    @Test("the stroke is the border's width and corners")
    func derivedFromTheBorder() {
        var settings = TilingSettings()
        settings.borderStyle.width = 3
        settings.borderStyle.cornerStyle = .square
        #expect(
            settings.windowStroke
                == WindowStroke(width: 3, cornerRadius: 0)
        )
        settings.borderStyle.cornerStyle = .rounded
        #expect(
            settings.windowStroke.cornerRadius
                == GeometryUtils.systemWindowCornerRadius
        )
        // The same clamp the ring draws with.
        settings.borderStyle.width = 99
        #expect(settings.windowStroke.width == BorderStyle.maxWidth)
    }

    /// A pre-#1742 file's per-stroke values are no longer read —
    /// the ring wins — and the rest of the file still decodes.
    @Test("an old file's drag width and radius are ignored")
    func oldDragKeysAreIgnored() throws {
        let json = #"""
            {"border": {"width": 3, "corner_style": "square"},
             "drag": {"corner_radius": 22,
                      "ghost": {"border_width": 9, "enabled": false},
                      "drop_zone": {"border_width": 1}}}
            """#
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: Data(json.utf8)
        )
        #expect(!decoded.dragGhost.enabled)
        let written = try JSONEncoder().encode(decoded)
        let root = try #require(
            JSONSerialization.jsonObject(with: written)
                as? [String: Any]
        )
        let drag = try #require(root["drag"] as? [String: Any])
        #expect(drag["corner_radius"] == nil)
        for visual in ["ghost", "drop_zone"] {
            let entry = try #require(drag[visual] as? [String: Any])
            #expect(entry["border_width"] == nil, "\(visual)")
        }
    }

    /// The corners still follow the border; the markers' widths are
    /// fixed since #2797, so their verbs name no replacement.
    @Test(
        "the per-stroke verbs are retired",
        arguments: [
            ("drag.set_ghost_border_width", "look is fixed"),
            ("drag.set_drop_zone_border_width", "look is fixed"),
            ("drag.set_corner_radius", "border.set_corner_style"),
        ]
    )
    @MainActor
    func retiredVerbsFail(verb: String, message: String) {
        let core = makeTestCore()
        let before = core.tiler.settings
        let response = core.execute(verb, args: [.number(4)])
        #expect(!response.isSuccess)
        #expect(response.error?.contains(message) == true)
        #expect(core.tiler.settings == before)
    }

    /// A drag marker stores no stroke of its own, so no path can
    /// split it from the border again (#754, #1739, #1742).
    @Test("a drag visual stores no width or radius")
    func dragVisualStoresNoStroke() {
        let labels = Mirror(reflecting: DragVisual.ghostDefault)
            .children.compactMap(\.label)
        #expect(labels.contains("enabled"))
        for label in labels {
            #expect(
                !label.localizedCaseInsensitiveContains("width")
                    && !label.localizedCaseInsensitiveContains("radius"),
                "DragVisual.\(label) is a per-stroke store"
            )
        }
        let dragLabels = Mirror(reflecting: TilingSettings())
            .children.compactMap(\.label)
            .filter { $0.hasPrefix("drag") }
        #expect(dragLabels.contains("dragGhost"))
        for label in dragLabels {
            #expect(
                !label.localizedCaseInsensitiveContains("radius")
                    && !label.localizedCaseInsensitiveContains("width"),
                "TilingSettings.\(label) is a per-stroke store"
            )
        }
    }

    /// Both drag render paths hand the markers the border's
    /// corners, through the one `dragMarkerLook` — the engine's and
    /// the Settings picture's (#2797, #3583). Every marker call hands
    /// the look, however many calls a path grows, and no path reads
    /// the stroke beside it.
    @Test("the drag paths hand over the border's stroke")
    func dragPathsReadTheStroke() async throws {
        let look = try Self.code(
            "Sources/KiwiDeskCore/Tiling/DragMarkerLook.swift"
        )
        let corner = "cornerRadius: windowStroke.cornerRadius"
        #expect(Self.count(corner, in: look) == 1)
        for (path, calls, handed) in [
            (
                "Sources/KiwiDeskCore/Tiling/KiwiCore+DragMove.swift",
                ["dragOverlay.showGhost(", "dragOverlay.showDropZone("],
                "look: look"
            ),
            (
                "Sources/KiwiDesk/Settings/Components/GapsAndBorders/"
                    + "GapsBordersPanelPreview.swift",
                ["DragVisualPreview("],
                "look: settings.dragMarkerLook"
            ),
        ] {
            let text = try Self.code(path)
            let made = calls.map { Self.count($0, in: text) }
            #expect(made.allSatisfy { $0 > 0 }, "\(path) draws \(made)")
            #expect(
                Self.count(handed, in: text) == made.reduce(0, +),
                "\(path): a marker call hands no look"
            )
            #expect(!text.contains("windowStroke"), "\(path) reads the stroke")
        }
        let move = try Self.code(
            "Sources/KiwiDeskCore/Tiling/KiwiCore+DragMove.swift"
        )
        #expect(Self.count("settings.dragMarkerLook", in: move) == 1)
    }

    /// The look carries the stroke's corners as settings state
    /// them, Rounded and Square alike (#3583).
    @Test("the drag look's corners are the stroke's")
    func dragLookTakesTheStroke() {
        var settings = TilingSettings()
        for style in [BorderStyle.CornerStyle.rounded, .square] {
            settings.borderStyle.cornerStyle = style
            #expect(
                settings.dragMarkerLook.cornerRadius
                    == settings.windowStroke.cornerRadius
            )
        }
        #expect(
            settings.dragMarkerLook.focusColor
                == settings.borderStyle.focusedColor
        )
    }

    /// Code only: a needle kept alive in a comment beside a literal
    /// must not count.
    private static func code(_ path: String) throws -> String {
        try source(path)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.components(separatedBy: "//")[0] }
            .joined(separator: "\n")
    }

    private static func count(_ needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    private static func source(_ path: String) throws -> String {
        var url = URL(fileURLWithPath: #filePath)
        while url.lastPathComponent != "Tests" {
            url.deleteLastPathComponent()
        }
        url.deleteLastPathComponent()
        return try String(
            contentsOf: url.appendingPathComponent(path),
            encoding: .utf8
        )
    }
}
