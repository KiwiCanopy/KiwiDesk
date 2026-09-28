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
        #expect(
            decoded.windowStroke
                == WindowStroke(width: 3, cornerRadius: 0)
        )
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

    @Test(
        "the per-stroke verbs are retired to the border's",
        arguments: [
            ("drag.set_ghost_border_width", "border.set_width"),
            ("drag.set_drop_zone_border_width", "border.set_width"),
            ("drag.set_corner_radius", "border.set_corner_style"),
        ]
    )
    @MainActor
    func retiredVerbsNameTheBorder(verb: String, replacement: String) {
        let core = makeTestCore()
        let response = core.execute(verb, args: [.number(4)])
        #expect(!response.isSuccess)
        #expect(response.error?.contains(replacement) == true)
        #expect(core.tiler.settings == TilingSettings())
    }
}
