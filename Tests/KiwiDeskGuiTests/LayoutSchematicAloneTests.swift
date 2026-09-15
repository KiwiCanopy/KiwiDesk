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
    @Test("the band reaches 1 exactly where a lone window differs")
    func bandFloorPerMode() {
        let shared = LayoutSchematic.windowCountRange
        for mode in LayoutMode.allCases {
            let band = LayoutSchematic.windowCountRange(for: mode)
            let differs = mode == .scrolling || mode == .stack
            #expect(band.lowerBound == (differs ? 1 : 2))
            #expect(band.upperBound == shared.upperBound)
        }
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
        #expect(filled.slotFraction == 1)
        // The kept slot is the one the row draws at any count.
        #expect(
            kept.slotFraction
                == scrolling(fill: false, windows: 3).slotFraction
        )
        #expect(kept.slotFraction < 1)
        // One slot, the focus, and no incoming window to mark.
        #expect(filled.row.slots == 0...0)
        #expect(!filled.drawsInsertionMark)
        #expect(!kept.drawsInsertionMark)
        // The toggle is inert above one window.
        #expect(
            scrolling(fill: true, windows: 2).slotFraction
                == scrolling(fill: false, windows: 2).slotFraction
        )
    }

    @Test("Scrolling: the lone slot is drawn where the engine rests it")
    func scrollingLoneRest() {
        let kept = scrolling(fill: false)
        let m = kept.metrics(along: 400)
        // The engine leaves a row shorter than the axis at the
        // leading edge, so the one slot starts where the screen
        // starts; a fill spans the whole screen.
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
            let span = schematic.masterSpan(
                horizontal ? size.width : size.height
            )
            let drawn = horizontal ? frame.width : frame.height
            #expect(abs(drawn - span) < 0.01)
            // The zone sits where a second window would leave
            // it: away from the stack's edge.
            switch position {
            case .right: #expect(frame.minX == 0)
            case .left: #expect(abs(frame.maxX - size.width) < 0.01)
            case .bottom: #expect(frame.minY == 0)
            case .top: #expect(abs(frame.maxY - size.height) < 0.01)
            }
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

    // MARK: - Fixtures

    private func scrolling(
        fill: Bool,
        windows: Int = 1
    ) -> ScrollingSchematic {
        ScrollingSchematic(
            orientation: .horizontal,
            anchor: .center,
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
