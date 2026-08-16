import Foundation
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// What the Gaps & Borders panel answers for (owner eye-confirm,
/// 2026-08-16).
///
/// The panel stands in for a whole area, and it was answering for
/// part of one: it drew the drag GHOST alone though the area's
/// editor draws ghost and drop zone as twins (#231), it never
/// drew the sticky mark though this area owns the mark's switch,
/// and it labelled none of its pictures.
///
/// Two of those are surfacing branches, which is why they are
/// guarded rather than trusted: a branch that stops being written
/// leaves every count and every offer-set assertion above it
/// green (`gui.md` ▸ a view drawing off a resolved answer owes a
/// needle naming the BRANCH).
@Suite("Gaps & Borders panel")
@MainActor
struct GapsBordersPanelTests {
    private func panelSource() throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/"
                    + "GapsAndBorders/GapsBordersPanelPreview.swift"
            )
        // Whitespace-squashed like every sibling scan, so a
        // needle survives swift-format rewrapping an argument
        // list across lines.
        return SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        .filter { !$0.isWhitespace }
    }

    /// Both halves of the drag pair, each fed its OWN visual.
    /// Needled on the argument rather than on the type, because
    /// two mounts of the same renderer fed the same value would
    /// satisfy a bare count while drawing one thing twice.
    @Test("the panel draws both drag visuals")
    func dragPairIsWhole() throws {
        let source = try panelSource()
        #expect(source.contains("visual:settings.dragGhost"))
        #expect(source.contains("visual:settings.dragDropZone"))
    }

    /// The area owns the sticky switch, so its panel shows the
    /// mark. Needled at the mount, since the renderer's default
    /// is `nil` — forgetting the argument is silent.
    @Test("the panel hands the border preview its sticky style")
    func stickyReachesThePreview() throws {
        #expect(
            try panelSource().contains("sticky:settings.stickyStyle")
        )
    }

    /// Every picture is named, and named from the CATALOG — a
    /// hand-typed title could drift from the card it answers for,
    /// and would need its own locale key besides.
    @Test("every picture carries a catalog heading")
    func picturesAreLabelled() throws {
        let source = try panelSource()
        for name in [
            "gapsCard", "focusBorder", "dragCard", "dragGhost",
            "dragDropZone",
        ] {
            #expect(
                source.contains(".gapsAndBorders.\(name)"),
                Comment(
                    rawValue: "\(name) no longer heads a picture"
                )
            )
        }
    }

    /// The mark follows its own toggle, both ways. This is the
    /// branch, read directly: the whole point of drawing it is
    /// that the reader sees the switch work before saving.
    @Test("the sticky mark follows the sticky toggle")
    func markFollowsItsToggle() {
        var style = StickyStyle()
        style.mark = true
        #expect(
            FocusBorderPreview(
                style: BorderStyle(),
                sticky: style
            ).stickyMark != nil
        )
        style.mark = false
        #expect(
            FocusBorderPreview(
                style: BorderStyle(),
                sticky: style
            ).stickyMark == nil
        )
        // And a mount that passes no style draws no mark — the
        // default that keeps this ONE renderer usable where the
        // subject is only the ring.
        #expect(
            FocusBorderPreview(style: BorderStyle()).stickyMark
                == nil
        )
    }

    /// The glyph is the ENGINE's, not a shape chosen here — the
    /// mark and the Space Bar badge are "one glyph everywhere"
    /// (#414), and a preview drawing a different one teaches a
    /// mark the app never renders.
    @Test("the drawn glyph is the engine's own")
    func glyphComesFromTheEngine() {
        var style = StickyStyle()
        style.mark = true
        let drawn = FocusBorderPreview(
            style: BorderStyle(),
            sticky: style
        ).stickyMark
        #expect(
            drawn?.symbol
                == StickyStyle.symbolName(for: .global)
        )
    }

    /// The Automatic sentinel. An EMPTY mark colour means the
    /// adaptive label colour, not "no colour" — `Color(kiwiHex:)`
    /// maps an unparseable hex to `.clear`, which drew the sticky
    /// and floating marks as holes at their shipped defaults.
    @Test("an empty mark colour is Automatic, not clear")
    func automaticIsNotClear() {
        #expect(Color.kiwiMark("") == Color.primary)
        #expect(Color.kiwiMark("#FF0000") != Color.primary)
        #expect(Color.kiwiMark("") != Color.clear)
        // WHICH paths carry the sentinel, as resolved membership
        // rather than as a restatement of the predicate. The
        // first cut asserted `path.hasSuffix(".color")` over
        // paths already filtered by `allowsAutomatic`, whose
        // definition IS that suffix — true by construction and
        // unable to fail (code review, 2026-08-16).
        let automatic = ColorPaletteKeys.all
            .filter(ColorPaletteKeys.allowsAutomatic)
        #expect(
            Set(automatic) == ["sticky.color", "floating.color"],
            Comment(
                rawValue:
                    "the adaptive set changed: "
                    + automatic.sorted().joined(separator: ", ")
            )
        )
        // And no ordinary `_color` path was admitted — the other
        // direction, which membership alone would not catch if a
        // third mark ever joined legitimately.
        for path in ColorPaletteKeys.all
        where path.hasSuffix("_color") {
            #expect(!ColorPaletteKeys.allowsAutomatic(path))
        }
    }
}
