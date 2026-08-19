import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

@Suite("App bar slot sizing math")
struct AppBarSlotSizingTests {
    @Test("item_size 0 uses the measured auto width, clamped")
    func autoSlot() {
        // The measured auto width passes through when sane.
        #expect(
            AppBarOverlay.slotLength(
                itemSize: 0,
                content: .iconAndTitle,
                thickness: 32,
                axis: 1000,
                autoWidth: 88
            ) == 88
        )
        // Clamped up to the icon minimum when the measurement is
        // tiny (icons never clip).
        #expect(
            AppBarOverlay.slotLength(
                itemSize: 0,
                content: .iconAndTitle,
                thickness: 32,
                axis: 1000,
                autoWidth: 10
            ) == 32
        )
        // Clamped down to a quarter of the bar when it's huge.
        #expect(
            AppBarOverlay.slotLength(
                itemSize: 0,
                content: .title,
                thickness: 32,
                axis: 1000,
                autoWidth: 900
            ) == 250
        )
    }

    @Test("Explicit item_size wins, clamped on both sides")
    func explicitSlot() {
        // The user's size as-is while it is sane.
        #expect(
            AppBarOverlay.slotLength(
                itemSize: 80,
                content: .iconAndTitle,
                thickness: 32,
                axis: 1000,
                autoWidth: 140
            ) == 80
        )
        // Too small: icons must survive — at least the
        // icon square.
        #expect(
            AppBarOverlay.slotLength(
                itemSize: 10,
                content: .iconAndTitle,
                thickness: 32,
                axis: 1000,
                autoWidth: 140
            ) == 32
        )
        // Too big: capped at a quarter of the bar.
        #expect(
            AppBarOverlay.slotLength(
                itemSize: 900,
                content: .iconAndTitle,
                thickness: 32,
                axis: 1000,
                autoWidth: 140
            ) == 250
        )
        // Tiny bar: the icon minimum beats the quarter cap.
        #expect(
            AppBarOverlay.slotLength(
                itemSize: 80,
                content: .iconAndTitle,
                thickness: 32,
                axis: 60,
                autoWidth: 140
            ) == 32
        )
    }

    @Test("Icon bars refuse slots smaller than the icon square")
    func iconMinimum() {
        #expect(
            AppBarOverlay.minimumSlot(
                thickness: 32,
                content: .iconAndTitle
            ) == 32
        )
        #expect(
            AppBarOverlay.minimumSlot(
                thickness: 32,
                content: .icon
            ) == 32
        )
        // Text-only bars keep just a sliver of legibility.
        #expect(
            AppBarOverlay.minimumSlot(
                thickness: 32,
                content: .title
            ) < 32
        )
    }

    @Test("Auto font size scales with thickness, clamped")
    func autoFontSize() {
        // The ladder lives on the STYLE (one resolution site
        // shared with the slot measurement and the GUI scene);
        // the default style's `fontSize` 0 is the auto arm.
        let auto = AppBarStyle()
        #expect(auto.fontSize == 0)
        let slim = auto.resolvedFontSize(forThickness: 20)
        let fat = auto.resolvedFontSize(forThickness: 48)
        #expect(slim < fat)
        // Extremes stay readable and inside the strip.
        #expect(auto.resolvedFontSize(forThickness: 4) == 9)
        #expect(auto.resolvedFontSize(forThickness: 400) == 28)
        // An explicit `font_size` wins over the ladder.
        var pinned = AppBarStyle()
        pinned.fontSize = 13
        #expect(
            pinned.resolvedFontSize(forThickness: 48) == 13
        )
    }

    @Test("Vertical bars render icon-only")
    func verticalContentCollapses() {
        // The stored preference survives; only rendering
        // collapses (QA 2026-07-19).
        #expect(
            AppBarStyle.Content.iconAndTitle.rendered(
                horizontal: false
            ) == .icon
        )
        #expect(
            AppBarStyle.Content.title.rendered(
                horizontal: false
            ) == .icon
        )
        #expect(
            AppBarStyle.Content.iconAndTitle.rendered(
                horizontal: true
            ) == .iconAndTitle
        )
    }
}
