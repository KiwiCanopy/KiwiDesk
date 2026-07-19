import CoreGraphics
import Foundation

/// The bar's nested option vocabularies, split from
/// AppBarStyle.swift (file-size ceiling). Same types, same
/// JSON spellings; the Codable conformance stays with the
/// struct (synthesized `encode` requires same-file).
extension AppBarStyle {
    /// How each tab is backed. Orthogonal to `activeIndicator`:
    /// the background is drawn the same on every tab, the
    /// indicator marks only the active one. An extensible set —
    /// more background treatments can join later.
    public enum TabBackground: String, Sendable, Codable {
        /// A box per tab, honoring `cornerRoundness`
        /// (roundness 0 = square).
        case boxed
        /// No per-tab box; names sit on one shared translucent
        /// strip.
        case plain
        /// A macOS 26 Liquid Glass plate under the items — one
        /// shared plate like `plain`, but a live glass material
        /// tinted by `background_color` (#390). macOS 26+ only:
        /// the value round-trips everywhere, but on older macOS it
        /// *renders* as `boxed` (see `rendered(glassAvailable:)`);
        /// the GUI only offers it where it can render.
        case material

        /// True when this platform can render the glass material.
        public static var glassAvailable: Bool {
            if #available(macOS 26, *) { return true }
            return false
        }

        /// The treatment actually painted: `material` degrades to
        /// `boxed` where glass is unavailable, so an older macOS
        /// opening a glass profile shows the default look rather
        /// than an unbacked strip — without rewriting the stored
        /// value. Pure (`glassAvailable` injected) for tests.
        public func rendered(glassAvailable: Bool) -> TabBackground {
            self == .material && !glassAvailable ? .boxed : self
        }

        /// The treatment painted on this platform.
        public var rendered: TabBackground {
            rendered(glassAvailable: Self.glassAvailable)
        }
    }

    /// How big the shared background plate is (QA 2026-07-19).
    /// Orthogonal to `TabBackground` — "what the plate is made
    /// of" vs "how far it reaches": `plain` and `material` both
    /// draw one shared plate and both honor this; `boxed` draws
    /// no shared plate, so the setting is inert there (the GUI
    /// greys it).
    public enum TabBackgroundFit: String, Sendable, Codable {
        /// The plate spans the whole strip edge-to-edge.
        case full
        /// The plate wraps the content run plus one box gap of
        /// breathing room per end — the Dock's read; falls back
        /// to `full` once the run overflows and scrolls
        /// (content fills the strip there, nothing to hug).
        case hug
    }

    /// How the active tab is marked. Orthogonal to
    /// `tabBackground`: works on any background.
    public enum ActiveIndicator: String, Sendable, Codable {
        /// An outlined border around the active tab.
        case ring
        /// An accent bar on the window-facing edge of the
        /// active tab.
        case edgeMark = "edge_mark"
        /// The active tab's slot is left empty — an empty slot
        /// marks the focused window.
        case gap
    }

    public enum Content: String, Sendable, Codable {
        case icon
        case name
        /// Truncation only ever eats the name; the icon
        /// always survives.
        case iconAndName = "icon_and_name"

        /// The content actually drawn: vertical bars render
        /// icon-only — letter-stacked names read terribly and
        /// rotated text is not native (QA 2026-07-19; the Space
        /// Bar settled the same rule for its front-app name).
        /// The stored preference round-trips, mirroring
        /// `TabBackground.rendered(glassAvailable:)`.
        public func rendered(horizontal: Bool) -> Content {
            horizontal ? self : .icon
        }
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
