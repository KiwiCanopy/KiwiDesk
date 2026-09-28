import CoreGraphics
import Foundation
import KiwiDeskCore
import SwiftUI
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
        LocalizationManager.shared.select("en")
        let slot = CrossReferenceRow.linkSlot
        #expect(GesturesShelfEntries.springLinkProse.contains(slot))
        for surface in [GestureSurface.spaceBar, .appBar] {
            #expect(surface.offProse?.contains(slot) == true)
        }
        #expect(GestureSurface.windows.offProse == nil)
    }

    /// The surfaces ask Core's own shelf predicates, across every
    /// pairing of the two bars — the default draft has an App Bar
    /// on, so without the off fixtures half of this could not fail.
    @Test(
        "a surface is off exactly when its bar is",
        arguments: [
            (true, true), (true, false), (false, true), (false, false),
        ]
    )
    func surfaceMatrix(spaceBar: Bool, appBar: Bool) {
        var settings = TilingSettings()
        settings.spaceBarStyle.enabled = spaceBar
        settings.monocle.appBar.enabled = appBar
        settings.scrolling.appBar.enabled = appBar
        #expect(settings.anyAppBarCanShow == appBar)
        #expect(!GestureSurface.windows.isOff(settings))
        #expect(GestureSurface.spaceBar.isOff(settings) == !spaceBar)
        #expect(GestureSurface.appBar.isOff(settings) == !appBar)
        #expect(
            GestureSurface.shelf.isOff(settings) == !(spaceBar || appBar)
        )
    }

    @Test("the default draft: the Space Bar on, a surface too")
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
            ("shortcuts.gestures.app_bar_hover", "appBar"),
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
        let drawer = try Self.source(
            Self.gestures + "GesturesDrawer.swift"
        )
        #expect(!drawer.contains("GreyOut("))
        let entry = Self.squash(
            try Self.source(Self.gestures + "GestureEntry.swift")
        )
        // One grey, built once and applied to the picture and the
        // sentence: never to the control, nor around the whole.
        #expect(entry.components(separatedBy: "GreyOut(").count == 2)
        #expect(
            entry.contains(
                "privatevardim:GreyOut{GreyOut(active:surface.isOff("
            )
        )
        #expect(entry.components(separatedBy: ".modifier(dim)").count == 3)
        #expect(!entry.contains("control().modifier(dim)"))
        let layout = try #require(entry.range(of: "GestureEntryLayout{"))
        let close = try #require(
            entry.range(
                of: "control()}",
                range: layout.upperBound..<entry.endIndex
            )
        )
        #expect(
            !entry[close.upperBound...].hasPrefix(".modifier(dim)"),
            "the grey wraps the whole entry"
        )
    }

    /// The control joins the sentence's column only where it
    /// fits there whole, and the layout asks this decision rather
    /// than one of its own.
    @Test("a control sits under the sentence only where it fits")
    func controlPlacement() throws {
        let plate = GesturePlate<EmptyView>.size.width
        #expect(
            GestureEntryLayout.fitsColumn(
                control: 360,
                plate: plate,
                width: 640,
                spacing: 14
            )
        )
        #expect(
            !GestureEntryLayout.fitsColumn(
                control: 503,
                plate: plate,
                width: 600,
                spacing: 14
            )
        )
        #expect(
            GestureEntryLayout.fitsColumn(
                control: 0,
                plate: plate,
                width: 0,
                spacing: 14
            )
        )
        let layout = Self.squash(
            try Self.source(Self.gestures + "GestureEntryLayout.swift")
        )
        #expect(layout.contains("inColumn:Self.fitsColumn("))
        #expect(layout.contains("m.inColumn?CGPoint(x:columnX,"))
    }

    /// Lays out real entries, with and without a control, at a
    /// width that keeps the control in the column and one that
    /// does not — an entry without a control hands the layout two
    /// children, not three, which once trapped. `@MainActor` for
    /// the renderer; four small renders.
    @Test("entries lay out with and without a control")
    @MainActor
    func entriesLayOut() throws {
        let settings = TilingSettings()
        for width in [700.0, 380.0] {
            let bare = GestureEntry(
                "Bare",
                surface: .windows,
                settings: settings
            ) { GesturePicture.Swap(t: $0) }
            let controlled = GestureEntry(
                "With a control",
                surface: .windows,
                settings: settings
            ) {
                GesturePicture.Edge(t: $0)
            } control: {
                MouseResizePicker(selection: .constant(.layout))
            }
            for view in [AnyView(bare), AnyView(controlled)] {
                let renderer = ImageRenderer(
                    content: view.frame(width: width)
                )
                let image = try #require(renderer.nsImage)
                #expect(abs(image.size.width - width) < 0.5)
                #expect(
                    image.size.height >= GesturePlate<EmptyView>.size.height
                )
            }
        }
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
        let screen = HomeCardBehaviorTile.screen
        let engine = QuitGridLayout.frames(
            for: ids,
            in: CGRect(origin: .zero, size: screen),
            minSize: shallow.minWindowSize,
            targetDepth: 1
        )
        let scaled = ids.compactMap { engine[$0] }.map {
            CGRect(
                x: $0.minX * size.width / screen.width,
                y: $0.minY * size.height / screen.height,
                width: $0.width * size.width / screen.width,
                height: $0.height * size.height / screen.height
            )
        }
        #expect(a.count == scaled.count)
        for (drawn, engine) in zip(a, scaled) {
            #expect(abs(drawn.minX - engine.minX) < 0.01)
            #expect(abs(drawn.minY - engine.minY) < 0.01)
            #expect(abs(drawn.width - engine.width) < 0.01)
            #expect(abs(drawn.height - engine.height) < 0.01)
        }
        // Every window keeps a real height at tile scale — the
        // shape this readout once lost to screen-point staggers.
        #expect(a.allSatisfy { $0.height > size.height / 10 })
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
