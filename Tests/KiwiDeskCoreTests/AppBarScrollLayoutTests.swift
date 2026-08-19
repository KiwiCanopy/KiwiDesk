import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

@Suite("App bar scroll & layout math")
struct AppBarScrollLayoutTests {
    @MainActor
    @Test("Auto width measures horizontally, standard vertically")
    func autoWidthMeasures() {
        let short = [item("Hi")]
        let long = [item("A Much Longer Window Title")]
        let style = AppBarStyle()
        let shortW = AppBarOverlay.autoSlotWidth(
            items: short,
            style: style,
            horizontal: true,
            thickness: 32
        )
        let longW = AppBarOverlay.autoSlotWidth(
            items: long,
            style: style,
            horizontal: true,
            thickness: 32
        )
        // A longer name yields a wider slot; measured, not fixed.
        #expect(longW > shortW)
        // Vertical bars render icon-only: the slot is the
        // icon square (QA 2026-07-19).
        #expect(
            AppBarOverlay.autoSlotWidth(
                items: long,
                style: style,
                horizontal: false,
                thickness: 32
            ) == 32
        )
    }

    private func item(_ name: String) -> AppBarOverlay.Item {
        AppBarOverlay.Item(
            id: WindowID(1),
            name: name,
            text: name,
            icon: nil
        )
    }

    @Test("Scroll offset follows the active item into view")
    func scrollFollowsFocus() {
        // 10 items of 100 (no gaps) in a 320 strip. Focusing
        // the last item scrolls all the way to the end — the
        // margin would ask for 696 but the clamp at
        // total - axis (680) wins; there is nothing beyond
        // the last item to keep clear of.
        #expect(
            AppBarOverlay.scrollOffset(
                current: 0,
                activeIndex: 9,
                slot: 100,
                gap: 0,
                count: 10,
                axis: 320,
                margin: 16
            ) == 680
        )
        // A middle item does keep the margin: item 5 must end
        // 16pt clear of the right edge -> 600 - 320 + 16.
        #expect(
            AppBarOverlay.scrollOffset(
                current: 0,
                activeIndex: 5,
                slot: 100,
                gap: 0,
                count: 10,
                axis: 320,
                margin: 16
            ) == 296
        )
        // Scrolling back to the first item pins at 0 — the
        // margin never pushes the offset negative.
        #expect(
            AppBarOverlay.scrollOffset(
                current: 696,
                activeIndex: 0,
                slot: 100,
                gap: 0,
                count: 10,
                axis: 320,
                margin: 16
            ) == 0
        )
        // An already-visible active item moves nothing.
        #expect(
            AppBarOverlay.scrollOffset(
                current: 100,
                activeIndex: 2,
                slot: 100,
                gap: 0,
                count: 10,
                axis: 320,
                margin: 16
            ) == 100
        )
    }

    @Test("Scroll offset clamps, and is 0 while items fit")
    func scrollClamps() {
        // Nil active index (manual arrow scroll): only clamp.
        #expect(
            AppBarOverlay.scrollOffset(
                current: 9999,
                activeIndex: nil,
                slot: 100,
                gap: 0,
                count: 10,
                axis: 320,
                margin: 16
            ) == 680
        )
        #expect(
            AppBarOverlay.scrollOffset(
                current: -50,
                activeIndex: nil,
                slot: 100,
                gap: 0,
                count: 10,
                axis: 320,
                margin: 16
            ) == 0
        )
        // Everything fits: no scrolling, whatever the state.
        #expect(
            AppBarOverlay.scrollOffset(
                current: 300,
                activeIndex: 1,
                slot: 100,
                gap: 0,
                count: 3,
                axis: 320,
                margin: 16
            ) == 0
        )
    }

    @Test("Drop index maps a drag position to its slot")
    func dropIndex() {
        // Slots of 100pt, 10pt apart, starting at 0.
        #expect(
            AppBarOverlay.dropIndex(
                center: 50,
                start: 0,
                slot: 100,
                gap: 10,
                count: 3
            ) == 0
        )
        #expect(
            AppBarOverlay.dropIndex(
                center: 165,
                start: 0,
                slot: 100,
                gap: 10,
                count: 3
            ) == 1
        )
        // Past the ends: clamped into the item range.
        #expect(
            AppBarOverlay.dropIndex(
                center: -40,
                start: 0,
                slot: 100,
                gap: 10,
                count: 3
            ) == 0
        )
        #expect(
            AppBarOverlay.dropIndex(
                center: 900,
                start: 0,
                slot: 100,
                gap: 10,
                count: 3
            ) == 2
        )
        // A centered / scrolled group shifts the mapping.
        #expect(
            AppBarOverlay.dropIndex(
                center: 60,
                start: 55,
                slot: 100,
                gap: 10,
                count: 3
            ) == 0
        )
    }

    @Test("Overflowing frames start at the scroll offset")
    func scrolledFrames() {
        let frames = AppBarOverlay.frames(
            lengths: Array(repeating: 100, count: 10),
            in: CGRect(x: 0, y: 0, width: 320, height: 32),
            gap: 0,
            horizontal: true,
            alignment: .center,
            scrolledBy: 250
        )
        #expect(frames[0].minX == -250)
        #expect(frames[3].minX == 50)
    }

    @Test("Frames line up along the axis, centered as a group")
    func framesCentered() {
        let frames = AppBarOverlay.frames(
            lengths: [100, 100],
            in: CGRect(x: 0, y: 0, width: 320, height: 32),
            gap: 10,
            horizontal: true,
            alignment: .center
        )
        // 210 used of 320: the group starts at 55.
        #expect(frames[0].minX == 55)
        #expect(frames[1].minX == 165)
        #expect(frames[0].height == 32)
        // Vertical bars stack top-down instead.
        let vertical = AppBarOverlay.frames(
            lengths: [40, 40],
            in: CGRect(x: 0, y: 0, width: 32, height: 100),
            gap: 0,
            horizontal: false,
            alignment: .center
        )
        #expect(vertical[0].minY == 10)
        #expect(vertical[1].minY == 50)
        #expect(vertical[1].width == 32)
    }
}
