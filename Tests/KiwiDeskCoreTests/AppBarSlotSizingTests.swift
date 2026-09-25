import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

@Suite("App bar slot sizing math")
struct AppBarSlotSizingTests {
    @Test("The measured auto width is the slot, clamped")
    func autoSlot() {
        // The measured auto width passes through when sane.
        #expect(
            AppBarOverlay.slotLength(
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
                content: .iconAndTitle,
                thickness: 32,
                axis: 1000,
                autoWidth: 10
            ) == 32
        )
        // Clamped down to a quarter of the bar when it's huge.
        #expect(
            AppBarOverlay.slotLength(
                content: .title,
                thickness: 32,
                axis: 1000,
                autoWidth: 900
            ) == 250
        )
    }

    @Test("A tiny bar keeps the icon minimum over the quarter cap")
    func tinyBarKeepsIcon() {
        #expect(
            AppBarOverlay.slotLength(
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
        let auto = AppBarLook()
        #expect(auto.fontSize == 0)
        let slim = auto.resolvedFontSize(forThickness: 20)
        let fat = auto.resolvedFontSize(forThickness: 48)
        #expect(slim < fat)
        // Extremes stay readable and inside the strip.
        #expect(auto.resolvedFontSize(forThickness: 4) == 9)
        #expect(auto.resolvedFontSize(forThickness: 400) == 28)
        // An explicit `font_size` wins over the ladder.
        var pinned = AppBarLook()
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
