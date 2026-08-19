import Foundation
import Testing

@testable import KiwiDeskCore

/// The title cap's arithmetic, and the fold that keeps a
/// profile written before the rename decodable. Both are pure —
/// no `KiwiCore` — which is why they are their own file; the
/// driver-level halves are in `AppBarItemTextTests.swift` and
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

    /// Both bars read ONE range, so the same window cannot read
    /// two lengths on one screen.
    @Test("Both bars clamp to the same range")
    func bothBarsShareOneRange() {
        var app = AppBarStyle()
        var space = SpaceBarStyle()
        app.titleCap = 5_000
        space.titleCap = 5_000
        #expect(
            app.resolvedTitleCap
                == AppBarStyle.titleCapRange.upperBound
        )
        #expect(space.resolvedTitleCap == app.resolvedTitleCap)
        app.titleCap = 0
        space.titleCap = 0
        #expect(
            app.resolvedTitleCap
                == AppBarStyle.titleCapRange.lowerBound
        )
        #expect(space.resolvedTitleCap == app.resolvedTitleCap)
    }
}

/// The two retired app-name spellings fold onto their title
/// equivalents instead of throwing. Not a compat promise — the
/// point is that a raw `Content.self` decode of a retired
/// spelling THROWS, which would have failed the whole profile
/// decode and reset every unrelated bar setting with it.
@Suite("Retired content spellings")
struct BarContentDecodeTests {
    @Test("The retired spellings fold onto titles")
    func retiredSpellingsFold() {
        #expect(AppBarStyle.Content.decoded("name") == .title)
        #expect(
            AppBarStyle.Content.decoded("icon_and_name")
                == .iconAndTitle
        )
        #expect(AppBarStyle.Content.decoded("icon") == .icon)
        #expect(AppBarStyle.Content.decoded("nonsense") == nil)
    }

    /// The whole point: a profile saved before the rename keeps
    /// its OTHER settings. A raw enum decode would have thrown
    /// past the sibling keys and handed back a default style.
    ///
    /// Deliberately `"name"` rather than `"icon_and_name"`: the
    /// latter folds onto `.iconAndTitle`, which is ALSO the
    /// default, so a decode that quietly dropped the fold and
    /// fell through to `?? defaults.content` produced the
    /// expected value for the wrong reason and this test passed
    /// under mutation (guard-prover, 2026-08-19). `"name"` folds
    /// to `.title`, which no fallback path can reach.
    @Test("A pre-rename profile keeps its other settings")
    func retiredProfileKeepsSiblings() throws {
        let json = """
            {
              "content": "name",
              "thickness": 44,
              "item_gap": 11,
              "fill_color": "#123456"
            }
            """
        let style = try JSONDecoder().decode(
            AppBarStyle.self,
            from: Data(json.utf8)
        )
        #expect(style.content == .title)
        #expect(style.content != AppBarStyle().content)
        #expect(style.thickness == 44)
        #expect(style.itemGap == 11)
        #expect(style.fillColor == "#123456")
    }

    /// The same fold on the per-layout override, whose decode is
    /// a separate hand-written site.
    @Test("A pre-rename layout override folds too")
    func retiredOverrideFolds() throws {
        let json = """
            {"content": "name", "item_gap": 7}
            """
        let bar = try JSONDecoder().decode(
            LayoutAppBar.self,
            from: Data(json.utf8)
        )
        #expect(bar.content == .title)
        #expect(bar.itemGap == 7)
    }

    /// `showsText` is asked at two sites (the refresh gate and
    /// the measurement); pin what it answers so a later
    /// text-free case cannot be missed at one of them.
    @Test("Only the icon case draws no text")
    func showsTextIsExhaustive() {
        #expect(!AppBarStyle.Content.icon.showsText)
        #expect(AppBarStyle.Content.title.showsText)
        #expect(AppBarStyle.Content.iconAndTitle.showsText)
    }
}
