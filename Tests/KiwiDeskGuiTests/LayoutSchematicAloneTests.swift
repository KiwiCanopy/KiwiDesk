import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The lone-window frame (#1389). "If one window, fill the
/// screen" is the first setting that makes one window draw two
/// ways, so the Scrolling and Stack previews reach a count of 1
/// and draw it; every other layout keeps the shared band, whose
/// floor `LayoutSchematicCountTests` holds.
///
/// Arithmetic, not scans (gui.md): the lone frame's derived
/// quantities are read directly, and the caption is compared
/// against itself under the toggle rather than against English.
/// `@MainActor` for the reason every schematic suite gives — the
/// quantities are `View` properties.
@Suite("Layout preview lone window (#1389)")
@MainActor
struct LayoutSchematicAloneTests {
    /// Derived, not restated: a layout's band reaches 1 exactly
    /// when its params carry `fillWhenAlone`, read off
    /// `TilingSettings` by reflection so a third layout gaining
    /// the flag reds here until its band moves.
    @Test("the band reaches 1 exactly where a lone window differs")
    func bandFloorPerMode() {
        let shared = LayoutSchematic.windowCountRange
        let params = Dictionary(
            uniqueKeysWithValues: Mirror(reflecting: TilingSettings())
                .children.compactMap { child in
                    child.label.map { ($0, child.value) }
                }
        )
        var flagged = 0
        for mode in LayoutMode.allCases {
            let band = LayoutSchematic.windowCountRange(for: mode)
            let differs =
                params[mode.rawValue].map { value in
                    Mirror(reflecting: value).children
                        .contains { $0.label == "fillWhenAlone" }
                } ?? false
            flagged += differs ? 1 : 0
            #expect(
                band.lowerBound == (differs ? 1 : 2),
                Comment(rawValue: "\(mode)")
            )
            #expect(band.upperBound == shared.upperBound)
        }
        // The derivation is reading a populated surface.
        #expect(flagged == 2)
    }

    @Test("a count outside a mode's band is held inside it")
    func countClamp() {
        #expect(LayoutSchematic.windowCount(1, for: .grid) == 2)
        #expect(LayoutSchematic.windowCount(1, for: .scrolling) == 1)
        #expect(LayoutSchematic.windowCount(1, for: .stack) == 1)
        #expect(LayoutSchematic.windowCount(40, for: .stack) == 12)
        #expect(LayoutSchematic.windowCount(5, for: .bsp) == 5)
    }

    @Test("Scrolling: one window fills or keeps its slot")
    func scrollingLoneSlot() {
        let filled = scrolling(fill: true)
        let kept = scrolling(fill: false)
        #expect(filled.lone && kept.lone)
        #expect(filled.slot(screenLen: 400) == 400)
        // The kept slot is the one the row draws at any count.
        #expect(
            kept.slot(screenLen: 400)
                == scrolling(fill: false, windows: 3)
                .slot(screenLen: 400)
        )
        #expect(kept.slot(screenLen: 400) < 400)
        // One slot, the focus, and no incoming window to mark.
        #expect(filled.row.slots == 0...0)
        #expect(!filled.drawsInsertionMark)
        #expect(!kept.drawsInsertionMark)
        // The toggle is inert above one window.
        #expect(
            scrolling(fill: true, windows: 2).slot(screenLen: 400)
                == scrolling(fill: false, windows: 2)
                .slot(screenLen: 400)
        )
    }

    @Test("Scrolling: the lone slot is drawn where the engine rests it")
    func scrollingLoneRest() {
        let kept = scrolling(fill: false, anchor: .follow)
        let m = kept.metrics(along: 400)
        // Under `follow` the engine leaves a row shorter than the
        // axis at the leading edge, so the one slot starts where
        // the screen starts (a fixed anchor rests it absolutely,
        // #1388 — `keptLoneNamesTheAnchor`); a fill spans the
        // whole screen.
        #expect(abs(m.focusCenter - m.slot / 2 - m.screenStart) < 0.01)
        let full = scrolling(fill: true).metrics(along: 400)
        #expect(abs(full.slot - full.screenLen) < 0.01)
    }

    @Test("Stack: one window fills or keeps the master zone")
    func stackLoneFrame() {
        let size = CGSize(width: 200, height: 100)
        let filled = stack(fill: true).loneFrame(in: size)
        #expect(filled == CGRect(origin: .zero, size: size))
        for position in StackParams.StackPosition.allCases {
            let schematic = stack(fill: false, position: position)
            let frame = schematic.loneFrame(in: size)
            let horizontal = position.splitsHorizontally
            let total = horizontal ? size.width : size.height
            let span = schematic.masterSpan(total)
            // The engine's own two-zone split is the authority
            // (#702): the lone frame IS its master region.
            let engine = StackLayout.regions(
                usable: CGRect(origin: .zero, size: size),
                position: position,
                masterSpan: span,
                stackSpan: total - StackSchematic.zoneGap - span,
                gap: StackSchematic.zoneGap
            )
            #expect(frame == engine.master)
            #expect(frame != engine.stack)
        }
    }

    @Test("the lone caption and its spoken form switch with the toggle")
    func loneWordsSwitch() {
        let filled = scrolling(fill: true)
        let kept = scrolling(fill: false)
        #expect(filled.caption != kept.caption)
        #expect(filled.axLabel != kept.axLabel)
        // The lone sentence is neither of the row's.
        let row = scrolling(fill: true, windows: 3)
        #expect(filled.caption != row.caption)
        #expect(kept.caption != row.caption)
        // A vertical row keeps a height, not a width — its own key.
        var vertical = kept
        vertical = ScrollingSchematic(
            orientation: .vertical,
            anchor: .center,
            slotSize: .auto,
            placement: .last,
            fillWhenAlone: false,
            windows: 1,
            scale: .panel
        )
        #expect(vertical.caption != kept.caption)
        let stackFilled = stack(fill: true)
        let stackKept = stack(fill: false)
        #expect(stackFilled.loneCaption != stackKept.loneCaption)
        #expect(stackFilled.loneAxLabel != stackKept.loneAxLabel)
    }

    /// A kept lone window under a fixed anchor rests where the
    /// anchor says (#1388), and its words say so — under `follow`
    /// it sits where the row starts and the sentence stays
    /// place-free. The drawn rest is the engine's: the fixed
    /// anchors centre / edge the one slot, `follow` leads it.
    @Test("a kept lone window names its anchor, and rests there")
    func keptLoneNamesTheAnchor() {
        let follow = scrolling(fill: false, anchor: .follow)
        for anchor in [ScrollingParams.Anchor.center, .start, .end] {
            let fixed = scrolling(fill: false, anchor: anchor)
            #expect(fixed.caption != follow.caption)
            #expect(fixed.axLabel != follow.axLabel)
            // Filled, the anchor is moot and the words say so.
            let filled = scrolling(fill: true, anchor: anchor)
            #expect(filled.caption == scrolling(fill: true).caption)
        }
        let m = { (a: ScrollingParams.Anchor) in
            scrolling(fill: false, anchor: a).metrics(along: 400)
        }
        let centre = m(.center)
        #expect(
            abs(
                centre.focusCenter
                    - (centre.screenStart + centre.screenLen / 2)
            ) < 0.01
        )
        let end = m(.end)
        #expect(
            abs(
                end.focusCenter + end.slot / 2
                    - (end.screenStart + end.screenLen)
            ) < 0.01
        )
        let lead = m(.follow)
        #expect(
            abs(lead.focusCenter - lead.slot / 2 - lead.screenStart) < 0.01
        )
    }

    // MARK: - Fixtures

    private func scrolling(
        fill: Bool,
        windows: Int = 1,
        anchor: ScrollingParams.Anchor = .center
    ) -> ScrollingSchematic {
        ScrollingSchematic(
            orientation: .horizontal,
            anchor: anchor,
            slotSize: .auto,
            placement: .last,
            fillWhenAlone: fill,
            windows: windows,
            scale: .panel
        )
    }

    private func stack(
        fill: Bool,
        position: StackParams.StackPosition = .right
    ) -> StackSchematic {
        StackSchematic(
            masterCount: 1,
            masterRatio: 0.6,
            overflowStyle: .cascadeOverflow,
            masterOrientation: .horizontal,
            stackPosition: position,
            placement: .first,
            fillWhenAlone: fill,
            windows: 1,
            scale: .panel
        )
    }
}
