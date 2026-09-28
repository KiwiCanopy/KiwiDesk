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
        // The plate's chain and the sentence's each end on `dim`;
        // nothing after the control — through the end of the body
        // — carries it, so the control and the whole stay live.
        #expect(
            entry.contains(
                ".id(hovering).accessibilityHidden(true).modifier(dim)"
            )
        )
        #expect(
            entry.contains(
                ".fixedSize(horizontal:false,vertical:true).modifier(dim)"
            )
        )
        let control = try #require(entry.range(of: "control()}"))
        let end = try #require(
            entry.range(
                of: "privatevardim:GreyOut",
                range: control.upperBound..<entry.endIndex
            )
        )
        #expect(!entry[control.upperBound..<end.lowerBound].contains("dim"))
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

}
