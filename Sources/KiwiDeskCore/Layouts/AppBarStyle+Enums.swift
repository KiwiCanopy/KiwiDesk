import CoreGraphics
import Foundation

/// The bar's nested option vocabularies, split from
/// AppBarStyle.swift (file-size ceiling). Same types, same
/// JSON spellings; the Codable conformance stays with the
/// struct (synthesized `encode` requires same-file).
extension AppBarStyle {
    /// The floor for `thickness` (pt), shared by both bars. Below
    /// this the plate/border stroke and the glyph run collide and
    /// the bar reads broken (QA 2026-07-19), so every entry point
    /// clamps to it: profile decode, the Lua/CLI setter, and the
    /// GUI slider's lower bound.
    public static let minThickness: CGFloat = 20

    /// True when this platform can render Liquid Glass (macOS 26+).
    /// Gates the `liquidGlass` finish everywhere: rendering falls
    /// back to the solid shape below 26, and the GUI hides the
    /// toggle there (#390).
    public static var glassAvailable: Bool {
        if #available(macOS 26, *) { return true }
        return false
    }

    /// WHERE the background is drawn — orthogonal both to
    /// `activeIndicator` (which marks only the active item) and to
    /// the `liquidGlass` finish (a colorless glass material laid
    /// over either shape on macOS 26). Boxed = a box per item
    /// (honors `cornerRoundness`); Plain = one shared strip.
    public enum BackgroundStyle: String, Sendable, Codable {
        /// A box per item, honoring `cornerRoundness`
        /// (roundness 0 = square).
        case boxed
        /// No per-item box; the items sit on one shared
        /// translucent strip.
        case plain
    }

    /// How big the shared background plate is (QA 2026-07-19).
    /// Orthogonal to `BackgroundStyle` — "where is it drawn"
    /// vs "how far does it reach": `plain` draws one shared plate
    /// and honors this; `boxed` draws no shared plate, so the
    /// setting is inert there (the GUI greys it).
    public enum BackgroundFit: String, Sendable, Codable {
        /// The plate spans the whole strip edge-to-edge.
        case full
        /// The plate wraps the content run plus one item gap of
        /// breathing room per end — the Dock's read; falls back
        /// to `full` once the run overflows and scrolls
        /// (content fills the strip there, nothing to hug).
        case hug
    }

    /// How the active item is marked. Orthogonal to
    /// `backgroundStyle`: works on any background.
    public enum ActiveIndicator: String, Sendable, Codable {
        /// An outline around the active item, tracing its shape at
        /// the bar's roundness (a capsule at max, square at 0).
        case outline
        /// An accent bar on the window-facing edge of the
        /// active item.
        case edgeMark = "edge_mark"
        /// The active item's slot is left empty — an empty slot
        /// marks the focused window.
        case gap
    }

    /// What an item draws. The text is the window's own
    /// **title**, never its app name: a bar of five Finder
    /// windows reading "Finder" five times names nothing the
    /// icon did not already say, while "Downloads" / "KiwiCall"
    /// tells them apart (owner 2026-08-19). The app name
    /// survives as the fallback in the two places a title
    /// cannot speak — an empty one (lazy-title apps, #160) and
    /// a collapsed group, whose members have several titles and
    /// no one of them is true. Both fallbacks are resolved by
    /// the driver, in `KiwiCore.barItemText`.
    /// `CaseIterable` is load-bearing:
    /// `BarTitleCapTests.showsTextIsExhaustive` asserts the case
    /// COUNT, so adding a case reds that test and forces a
    /// ruling on whether the new one draws text — do not drop
    /// it as "unused".
    public enum Content: String, Sendable, Codable, CaseIterable {
        case icon
        case title
        /// Truncation only ever eats the title; the icon
        /// always survives.
        case iconAndTitle = "icon_and_title"

        /// The content actually drawn: vertical bars render
        /// icon-only — letter-stacked titles read terribly and
        /// rotated text is not native (QA 2026-07-19; the Space
        /// Bar settled the same rule for its front segment).
        /// The stored preference round-trips, mirroring
        /// `BackgroundStyle.rendered(glassAvailable:)`.
        public func rendered(horizontal: Bool) -> Content {
            horizontal ? self : .icon
        }

        /// Whether the drawn content carries text at all. Ask
        /// this rather than re-spelling `!= .icon`, so a later
        /// text-free case cannot be missed at a call site;
        /// `BarTitleCapTests.showsTextIsExhaustive` asserts the
        /// case COUNT, so a new one reds it and has to be ruled
        /// on here.
        ///
        /// A consumer deciding for a PAINTED bar asks it of
        /// `AppBarStyle.renderedContent`, which folds in the
        /// vertical collapse. No such consumer remains: the
        /// title-refresh gate left in #937 (announced titles
        /// made every item a consumer) and the GUI's title-cap
        /// grey-out followed it out (same corollary — the cap
        /// binds the announced title too).
        ///
        /// Two sites ask the raw `content` instead, and may only
        /// because each already stands on a horizontal-only
        /// path: `AppBarOverlay+Sizing`'s text measurement,
        /// behind its own `guard horizontal`, and
        /// `layoutHorizontal`, which by name never runs on a
        /// vertical bar. Moving either off that path owes it
        /// `renderedContent` — the collapse is the whole reason
        /// the gate exists.
        public var showsText: Bool { self != .icon }
    }

    /// Where the item group sits along the bar's long axis
    /// (#293 QA). Values are edge-relative (`start`/`end`),
    /// never `left`/`right` — the same reasoning that made
    /// `edge` absolute: correct across all four edges without
    /// a per-edge remap. A left bar's `start` is its top; a
    /// top bar's `start` is its left. Shared by both bars
    /// (`SpaceBarStyle.Alignment` aliases this). Once an App
    /// Bar group overflows and scrolls, the three collapse to
    /// the same visual (the group starts at the scroll
    /// offset).
    public enum BarAlignment: String, Sendable, Codable,
        CaseIterable
    {
        case start
        case center
        case end
    }
}
