import Foundation
import Testing

@testable import KiwiDeskCore

/// The title cap's arithmetic, and the fold that keeps a
/// profile written before the rename decodable. Both are pure —
/// no `KiwiCore` — which is why they are their own file; the
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
    /// `docs/lua-reference.md` and `docs/user-guide.md` all
    /// state "8-80, default 25" for both — an unguarded number
    /// restated in three places is what `rule-authoring.md`
    /// bans.
    @Test("Both bars default to the same cap")
    func bothBarsDefaultAlike() {
        #expect(AppBarStyle().titleCap == 25)
        #expect(SpaceBarStyle().titleCap == 25)
        #expect(
            AppBarStyle().titleCap == SpaceBarStyle().titleCap,
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

/// A `content` value this enum no longer knows must fall back,
/// not throw.
///
/// The retired `name` / `icon_and_name` spellings are the reason
/// the decode goes through `String` rather than `Content.self`,
/// and a hand-edit typo reaches the same path. Nothing folds them
/// onto a title mode — §5 bans compatibility aliases pre-release,
/// so an old profile simply opens at the default and the user
/// re-picks. What must NOT happen is the throw: `Content.self`
/// raises `DecodingError.dataCorrupted` on an unknown raw value,
/// which fails the whole `init(from:)` and resets every unrelated
/// bar setting in the struct.
@Suite("Unreadable content values")
struct ContentDecodeFallbackTests {
    /// The sibling settings are the assertion. A decode that
    /// threw would lose thickness, gap and colour too — which is
    /// the damage, not the content field itself.
    @Test("A retired spelling falls back and keeps its siblings")
    func retiredSpellingKeepsSiblings() throws {
        for retired in ["name", "icon_and_name"] {
            let json = """
                {
                  "content": "\(retired)",
                  "thickness": 44,
                  "item_gap": 11,
                  "fill_color": "#123456"
                }
                """
            let style = try JSONDecoder().decode(
                AppBarStyle.self,
                from: Data(json.utf8)
            )
            #expect(style.content == AppBarStyle().content)
            #expect(style.thickness == 44)
            #expect(style.itemGap == 11)
            #expect(style.fillColor == "#123456")
        }
    }

    /// Not special-cased to the two retired words — any
    /// unreadable value takes the same path, which is what makes
    /// this a decode rule rather than a rename shim.
    @Test("A typo falls back the same way")
    func typoFallsBack() throws {
        let json = """
            {"content": "not_a_mode", "thickness": 37}
            """
        let style = try JSONDecoder().decode(
            AppBarStyle.self,
            from: Data(json.utf8)
        )
        #expect(style.content == AppBarStyle().content)
        #expect(style.thickness == 37)
    }

    /// A live spelling still decodes to itself — otherwise the
    /// two tests above would pass on a decode that ignored the
    /// key entirely. `.title` is deliberately not the default.
    @Test("A live spelling still decodes")
    func liveSpellingDecodes() throws {
        let json = """
            {"content": "title"}
            """
        let style = try JSONDecoder().decode(
            AppBarStyle.self,
            from: Data(json.utf8)
        )
        #expect(style.content == .title)
        #expect(style.content != AppBarStyle().content)
    }

    /// The layout override's decode is a separate hand-written
    /// site. There the fallback is nil — "no override" — which
    /// inherits the global, the right answer for a retired
    /// spelling.
    @Test("An override falls back to inheriting")
    func overrideFallsBackToNil() throws {
        let json = """
            {"content": "icon_and_name", "item_gap": 7}
            """
        let bar = try JSONDecoder().decode(
            LayoutAppBar.self,
            from: Data(json.utf8)
        )
        #expect(bar.content == nil)
        #expect(bar.itemGap == 7)
    }

    /// ...and a live one still overrides, for the same reason
    /// `liveSpellingDecodes` exists.
    @Test("A live override still applies")
    func liveOverrideApplies() throws {
        let json = """
            {"content": "icon"}
            """
        let bar = try JSONDecoder().decode(
            LayoutAppBar.self,
            from: Data(json.utf8)
        )
        #expect(bar.content == .icon)
    }

    /// `showsText` gates the refresh, the slot measurement and
    /// the GUI grey-out; pin what it answers so a later
    /// text-free case cannot be missed at one of them.
    @Test("Only the icon case draws no text")
    func showsTextIsExhaustive() {
        #expect(!AppBarStyle.Content.icon.showsText)
        #expect(AppBarStyle.Content.title.showsText)
        #expect(AppBarStyle.Content.iconAndTitle.showsText)
    }
}
