import CoreGraphics
import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Shortcuts & Gestures ▸ Mouse & trackpad (#1726): where the
/// drawer mounts, what left Behavior for it, how its entries grey,
/// and the Behavior card's replacement picture.
@Suite("Mouse & trackpad drawer")
struct GesturesDrawerTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let gestures =
        "Sources/KiwiDesk/Settings/Components/Gestures/"

    private static func source(_ path: String) throws -> String {
        SourceScan.stripComments(
            try String(
                contentsOf: root.appendingPathComponent(path),
                encoding: .utf8
            )
        )
    }

    private static func squash(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined()
    }

    @Test("every pointer sentence places its link")
    @MainActor
    func pointersPlaceTheirLink() {
        let slot = CrossReferenceRow.linkSlot
        #expect(GesturesShelfEntries.springLinkProse.contains(slot))
        for surface in [GestureSurface.spaceBar, .appBar] {
            #expect(surface.offProse?.contains(slot) == true)
        }
        #expect(GestureSurface.windows.offProse == nil)
    }

    /// The surfaces ask Core's own shelf predicates.
    @Test("a surface is off exactly when its bar is")
    func surfacesAskCore() {
        var settings = TilingSettings()
        #expect(!GestureSurface.windows.isOff(settings))
        settings.spaceBarStyle.enabled = false
        #expect(GestureSurface.spaceBar.isOff(settings))
        #expect(
            GestureSurface.shelf.isOff(settings)
                == !settings.anyAppBarCanShow
        )
        #expect(
            GestureSurface.appBar.isOff(settings)
                == !settings.anyAppBarCanShow
        )
        settings.spaceBarStyle.enabled = true
        #expect(!GestureSurface.spaceBar.isOff(settings))
        #expect(!GestureSurface.shelf.isOff(settings))
    }

    /// Each entry names the surface it teaches, located by its own
    /// text key: swapping two entries' surfaces reds here.
    @Test(
        "each entry greys on its own surface",
        arguments: [
            ("shortcuts.gestures.swap", "windows"),
            ("shortcuts.gestures.edge", "windows"),
            ("shortcuts.gestures.follow_focus", "windows"),
            ("shortcuts.gestures.drop_on_space", "spaceBar"),
            ("shortcuts.gestures.glyph_click", "spaceBar"),
            ("shortcuts.gestures.overflow_menu", "spaceBar"),
            ("shortcuts.gestures.glyph_hover", "spaceBar"),
            ("shortcuts.gestures.shelf_scroll", "shelf"),
            ("shortcuts.gestures.app_bar", "appBar"),
        ]
    )
    func entryNamesItsSurface(key: String, surface: String) throws {
        var all = ""
        for file in ["GesturesDrawer.swift", "GesturesShelfEntries.swift"] {
            all += Self.squash(try Self.source(Self.gestures + file))
        }
        let start = try #require(all.range(of: "\"\(key)\""))
        let rest = all[start.upperBound...]
        let call =
            rest.range(of: "GestureEntry(").map {
                rest[..<$0.lowerBound]
            } ?? rest
        #expect(call.contains("surface:.\(surface),"))
    }

    /// The spring text is interpolated, so it is located by its
    /// argument rather than its key.
    @Test("the spring entry greys on the Space Bar")
    func springNamesItsSurface() throws {
        let body = Self.squash(
            try Self.source(Self.gestures + "GesturesShelfEntries.swift")
        )
        #expect(body.contains("springText,surface:.spaceBar,"))
    }

    /// A reason is readable while what it explains is dimmed: the
    /// group greys nothing itself, and the entry greys its
    /// explainer, never the control below it.
    @Test("reasons and controls sit outside the grey")
    func reasonsSitOutsideTheGrey() throws {
        let group = try Self.source(
            Self.gestures + "GesturesShelfEntries.swift"
        )
        #expect(!group.contains("GreyOut("))
        #expect(group.contains("ForEach(offReasons"))
        let entry = Self.squash(
            try Self.source(Self.gestures + "GestureEntry.swift")
        )
        let grey = try #require(
            entry.range(
                of: "explainer.modifier(GreyOut(active:surface.isOff("
            )
        )
        let control = try #require(entry.range(of: "control()"))
        #expect(grey.upperBound < control.lowerBound)
    }

    @Test("the drawer mounts above the layer header")
    func mountsAboveTheLayerHeader() throws {
        let body = try Self.source(
            "Sources/KiwiDesk/Settings/Sections/ShortcutsSection.swift"
        )
        let drawer = try #require(
            body.range(of: "GesturesDrawer(model: model)")
        )
        let header = try #require(body.range(of: "ShortcutsHeader("))
        #expect(drawer.lowerBound < header.lowerBound)
        #expect(
            body.components(separatedBy: "GesturesDrawer(").count
                == 2,
            "the drawer mounts exactly once"
        )
    }

    /// No Behavior file draws either moved control any more.
    @Test("Behavior no longer draws the mouse rows")
    func behaviorDropsTheMouseRows() throws {
        let settings = Self.root.appendingPathComponent(
            "Sources/KiwiDesk/Settings"
        )
        var files = try SourceScan.swiftSources(
            under: settings.appendingPathComponent("Components/Behavior")
        )
        files += try SourceScan.swiftSources(
            under: settings.appendingPathComponent("Sections")
        ).filter { $0.lastPathComponent.hasPrefix("BehaviorSection") }
        #expect(files.count >= 2)
        for file in files {
            let body = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            #expect(!body.contains("config.settings.mouseResize"))
            #expect(!body.contains("mouse.followsFocus"))
            #expect(!body.contains("MouseResizePicker("))
        }
    }

    /// The Behavior card's picture is the engine's quit grid for
    /// the draft's target depth, and its body draws that answer.
    /// `@MainActor` because the tile is a `View`; two small layouts.
    @Test("the Behavior tile draws the engine's quit grid")
    @MainActor
    func behaviorTileFollowsTheDepth() throws {
        var shallow = TilingSettings()
        shallow.quitGridTargetDepth = 1
        var deep = TilingSettings()
        deep.quitGridTargetDepth = 20
        let size = CGSize(width: 160, height: 100)
        let a = HomeCardBehaviorTile.frames(in: size, settings: shallow)
        let b = HomeCardBehaviorTile.frames(in: size, settings: deep)
        #expect(a.count == HomeCardBehaviorTile.sampleCount)
        #expect(a != b, "the target depth changed nothing")
        let ids = (1...HomeCardBehaviorTile.sampleCount)
            .map { WindowID(UInt32($0)) }
        let engine = QuitGridLayout.frames(
            for: ids,
            in: CGRect(origin: .zero, size: size),
            minSize: 6,
            targetDepth: 1
        )
        #expect(a == ids.compactMap { engine[$0] })
        let tile = try Self.source(
            "Sources/KiwiDesk/Settings/HomeCardPlate+Desk.swift"
        )
        #expect(
            Self.squash(tile).contains(
                "letframes=Self.frames(in:proxy.size,settings:settings)"
            )
        )
    }
}
