import CoreGraphics
import Foundation
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// How a Mouse & trackpad entry lays out (#1726), and the Behavior
/// card's quit-grid readout, split from `GesturesDrawerTests` for
/// size. `@MainActor` for the renderer; a handful of small renders.
@Suite("Mouse & trackpad layout")
@MainActor
struct GesturesLayoutTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    private static func squash(_ path: String) throws -> String {
        SourceScan.stripComments(
            try String(
                contentsOf: root.appendingPathComponent(path),
                encoding: .utf8
            )
        )
        .split(whereSeparator: \.isWhitespace).joined()
    }

    private func height<V: View>(_ view: V, width: CGFloat) throws
        -> CGFloat
    {
        let renderer = ImageRenderer(content: view.frame(width: width))
        return try #require(renderer.nsImage).size.height
    }

    /// The control joins the sentence's column only where it fits
    /// there whole, and the layout asks this one decision.
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
        // Between the limits with and without the spacing (466 and
        // 480 at 600): a fit test that forgot the gap would pass it.
        #expect(
            !GestureEntryLayout.fitsColumn(
                control: 470,
                plate: plate,
                width: 600,
                spacing: 14
            )
        )
        let layout = try Self.squash(
            "Sources/KiwiDesk/Settings/Components/Gestures/"
                + "GestureEntryLayout.swift"
        )
        #expect(layout.contains("letinColumn=Self.fitsColumn("))
        #expect(layout.contains("at:Self.controlOrigin(inColumn:m.inColumn,"))
        // Beside: under the sentence, at the column's edge. Below:
        // under the taller of plate and sentence, at the entry's.
        let bounds = CGRect(x: 10, y: 20, width: 600, height: 200)
        let size = GesturePlate<EmptyView>.size
        let sentence = CGSize(width: 300, height: 17)
        #expect(
            GestureEntryLayout.controlOrigin(
                inColumn: true,
                in: bounds,
                plate: size,
                sentence: sentence,
                spacing: 14,
                gap: 8
            ) == CGPoint(x: 10 + size.width + 14, y: 20 + 17 + 8)
        )
        #expect(
            GestureEntryLayout.controlOrigin(
                inColumn: false,
                in: bounds,
                plate: size,
                sentence: sentence,
                spacing: 14,
                gap: 8
            ) == CGPoint(x: 10, y: 20 + size.height + 8)
        )
    }

    /// Real entries at a width that keeps the control beside the
    /// picture and one that drops it under the row: a bare entry
    /// is the plate's height at both, and one with a control grows
    /// by at least that control's row only where it falls back. An
    /// entry with no control is two children, not three — which
    /// once trapped.
    @Test("an entry grows only where its control drops below")
    func entriesLayOut() throws {
        let settings = TilingSettings()
        let wide: CGFloat = 700
        let narrow: CGFloat = 380
        func bare() -> some View {
            GestureEntry(
                "Bare",
                surface: .windows,
                settings: settings
            ) { GesturePicture.Swap(t: $0) }
        }
        func controlled() -> some View {
            GestureEntry(
                "With a control",
                surface: .windows,
                settings: settings
            ) {
                GesturePicture.Edge(t: $0)
            } control: {
                MouseResizePicker(selection: .constant(.layout))
            }
        }
        let bareWide = try height(bare(), width: wide)
        let bareNarrow = try height(bare(), width: narrow)
        #expect(abs(bareWide - bareNarrow) < 0.5)
        #expect(bareWide >= GesturePlate<EmptyView>.size.height)
        let beside = try height(controlled(), width: wide)
        let below = try height(controlled(), width: narrow)
        // Beside the picture the control fits in the plate's height;
        // below the row it adds a row of its own.
        #expect(abs(beside - bareWide) < 0.5)
        #expect(below > beside + 20)
    }

    /// A text control that wraps where it is placed is measured
    /// wrapped: the entry grows by its extra line rather than
    /// drawing it over what follows.
    @Test("a wrapping control is measured at the width it gets")
    func wrappingControlGrows() throws {
        let settings = TilingSettings()
        let long = String(repeating: "Move the pointer along ", count: 4)
        func entry() -> some View {
            GestureEntry(
                "Short",
                surface: .windows,
                settings: settings
            ) {
                GesturePicture.FollowFocus(t: $0)
            } control: {
                Toggle(long, isOn: .constant(true))
            }
        }
        // At 300 pt the label drops under the row and wraps onto
        // several lines; measured as one line, the entry would come
        // out a line or two short and the rest would overdraw.
        let line = try height(
            Toggle("Move", isOn: .constant(true)),
            width: 300
        )
        let narrow = try height(entry(), width: 300)
        let floor = GesturePlate<EmptyView>.size.height + 8 + 2 * line
        #expect(narrow >= floor)
    }

    /// The Behavior card's picture is the engine's quit grid for
    /// the draft's depth, laid out on a real screen and scaled to
    /// the tile, and its body draws that answer.
    @Test("the Behavior tile draws the engine's quit grid")
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
        let sx = size.width / screen.width
        let sy = size.height / screen.height
        let scaled = ids.compactMap { engine[$0] }
        #expect(a.count == scaled.count)
        for (drawn, want) in zip(a, scaled) {
            #expect(abs(drawn.minX - want.minX * sx) < 0.01)
            #expect(abs(drawn.minY - want.minY * sy) < 0.01)
            #expect(abs(drawn.width - want.width * sx) < 0.01)
            #expect(abs(drawn.height - want.height * sy) < 0.01)
        }
        // Every window keeps a real height at tile scale — the
        // shape this readout once lost to screen-point staggers.
        #expect(a.allSatisfy { $0.height > size.height / 10 })
        let tile = try Self.squash(
            "Sources/KiwiDesk/Settings/HomeCardPlate+Desk.swift"
        )
        #expect(
            tile.contains(
                "letframes=Self.frames(in:proxy.size,settings:settings)"
            )
        )
    }
}
