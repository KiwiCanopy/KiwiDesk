import Foundation
import Testing

@testable import KiwiDeskCore

/// The title cap's arithmetic. It is pure — no `KiwiCore` —
/// which is why it is its own file; the
/// driver-level halves are in `BarTitleTextTests.swift` and
/// `BarTitleRefreshTests.swift`.
@Suite("Bar titles")
struct BarTitleCapTests {
    @Test("A title inside the cap is untouched")
    func shortTitleUnchanged() {
        #expect(
            AppBarStyle.cappedTitle("Downloads", to: 25)
                == "Downloads"
        )
    }

    /// The boundary both ways: a title exactly at the cap must
    /// not gain an ellipsis it does not need.
    @Test("The cap is inclusive")
    func exactlyAtCapUnchanged() {
        let title = String(repeating: "a", count: 25)
        #expect(AppBarStyle.cappedTitle(title, to: 25) == title)
        #expect(
            AppBarStyle.cappedTitle(title + "b", to: 25)
                == title + "…"
        )
    }

    /// The ellipsis marks what was dropped; it is not charged
    /// against the cap. A reader who set 25 sees 25 characters
    /// of title plus the marker, not 24 and a marker.
    @Test("The ellipsis is not charged against the cap")
    func ellipsisIsNotCounted() {
        let capped = AppBarStyle.cappedTitle(
            "TanStack Start: Full-Stack React Framework",
            to: 25
        )
        #expect(capped == "TanStack Start: Full-Stac…")
        #expect(capped.dropLast().count == 25)
    }

    /// Characters, not UTF-16 units. A ghostty tab titled
    /// "◐ app bar title truncation" must not spend two of its
    /// budget on the leading glyph, and a flag or family emoji
    /// (several scalars, one grapheme) must not spend five.
    @Test("The cap counts graphemes, not UTF-16 units")
    func capCountsGraphemes() {
        let emoji = String(repeating: "👨‍👩‍👧‍👦", count: 10)
        #expect(emoji.utf16.count > 10)
        #expect(
            AppBarStyle.cappedTitle(emoji, to: 10) == emoji,
            "ten graphemes must fit a cap of ten"
        )
        let capped = AppBarStyle.cappedTitle(emoji, to: 3)
        #expect(capped.dropLast().count == 3)
    }

    /// The shipped default, pinned on both bars and pinned as
    /// EQUAL.
    ///
    /// `bothBarsShareOneRange` below proves the clamp shares one
    /// range; it says nothing about where the two bars start.
    /// Moving either default was inert across the whole suite
    /// (guard-prover, 2026-08-19), while the commit message,
    /// `docs/lua-reference.md`, `docs/user-guide.md` and
    /// `docs/design-decisions.md` all state the range and the
    /// default for both — an unguarded number restated in four
    /// places is what `rule-authoring.md` bans.
    ///
    /// The number itself is a TASTE call and this is the home
    /// for its argument (tests.md, #1021). It was 25 until
    /// #1171. The bars show window TITLES rather than app names
    /// by default, and 25 characters of a title makes every item
    /// wide — every item on a bar is sized from the widest, so a
    /// long default spends the whole bar's width before the user
    /// has chosen anything. The owner tested 10 against a 12-14
    /// middle ground and ruled 10 (2026-08-31). Retuning it
    /// again means moving this pin, the two styles and the four
    /// prose copies together, which is the point of the pin.
    @Test("Both bars default to the same cap")
    func bothBarsDefaultAlike() {
        #expect(AppBarStyle().titleCap == 10)
        #expect(SpaceBarStyle().frontAppTitleCap == 10)
        #expect(
            AppBarStyle().titleCap == SpaceBarStyle().frontAppTitleCap,
            "the same window must not read two lengths"
        )
        // ...and the default is inside the range it clamps to,
        // so a fresh install never starts clamped.
        #expect(
            AppBarStyle.titleCapRange.contains(
                AppBarStyle().titleCap
            )
        )
    }

    /// Both bars read ONE range, so the same window cannot read
    /// two lengths on one screen.
    @Test("Both bars clamp to the same range")
    func bothBarsShareOneRange() {
        var app = AppBarLook()
        var space = SpaceBarLook()
        app.titleCap = 5_000
        space.frontAppTitleCap = 5_000
        #expect(
            app.resolvedTitleCap
                == AppBarStyle.titleCapRange.upperBound
        )
        #expect(space.resolvedFrontAppTitleCap == app.resolvedTitleCap)
        app.titleCap = 0
        space.frontAppTitleCap = 0
        #expect(
            app.resolvedTitleCap
                == AppBarStyle.titleCapRange.lowerBound
        )
        #expect(space.resolvedFrontAppTitleCap == app.resolvedTitleCap)
    }
}
