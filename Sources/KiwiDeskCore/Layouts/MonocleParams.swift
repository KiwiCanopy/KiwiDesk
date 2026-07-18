import CoreGraphics
import Foundation

/// Monocle tuning: orientation (which focus axis cycles
/// through the windows) and the indicator bar listing them.
/// The bar's look is global (`AppBarStyle`); this layout only
/// carries its own `enabled` + overrides (`bar`).
public struct MonocleParams: Sendable, Equatable, AppBarHosting {
    /// Which focus axis cycles through the monocle windows —
    /// and, with it, which edges the indicator bar may sit on.
    public enum Orientation: String, Sendable, Codable {
        /// `focus("left"/"right")` cycles; bar on top/bottom.
        case horizontal
        /// `focus("up"/"down")` cycles; bar on left/right.
        case vertical
    }

    public var orientation: Orientation = .horizontal
    /// Whether the focus cycle wraps past the ends (#168). Unlike
    /// Whether moving focus past the last window wraps to the
    /// first (and the reverse). Defaults **off**, matching the
    /// other array-order layouts (scrolling/track) — one default
    /// across all three. Turn it on for carousel-style cycling.
    /// `swap` never wraps. Per-layout, like the scrolling/track
    /// wrap toggles.
    public var wrapFocus = false
    /// Where a new window lands in the flat array — and, since
    /// monocle shows one window at a time, where it sits in the
    /// focus cycle. `.first` by default: a new window comes to
    /// the front of the carousel (the stack-master instinct),
    /// never buried mid-cycle. The same `SpawnPlacement`
    /// vocabulary every other layout uses.
    public var newWindowPlacement: SpawnPlacement = .first
    public var appBar = LayoutAppBar()
    /// Per-space overrides (`layout.monocle.override[space_id]`),
    /// resolved via `TilingSettings.resolvedMonocle(for:)`.
    public var override: [SpaceID: MonocleOverride] = [:]

    public init() {}
}

// MARK: - Codable

extension MonocleParams: Codable {
    private enum CodingKeys: String, CodingKey {
        case orientation
        case wrapFocus = "wrap_focus"
        case newWindowPlacement = "new_window_placement"
        case appBar = "app_bar"
        case override
    }

    /// Manual decoding: profiles saved before a field existed
    /// must keep loading (missing keys fall back to defaults).
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        let defaults = MonocleParams()
        orientation =
            try container.decodeIfPresent(
                Orientation.self,
                forKey: .orientation
            ) ?? defaults.orientation
        wrapFocus =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .wrapFocus
            ) ?? defaults.wrapFocus
        newWindowPlacement =
            try container.decodeIfPresent(
                SpawnPlacement.self,
                forKey: .newWindowPlacement
            ) ?? defaults.newWindowPlacement
        appBar =
            try container.decodeIfPresent(
                LayoutAppBar.self,
                forKey: .appBar
            ) ?? defaults.appBar
        override =
            try container.decodeIfPresent(
                [SpaceID: MonocleOverride].self,
                forKey: .override
            ) ?? [:]
    }

    /// Manual encode so the per-space override map stays sparse
    /// (absent when empty), unlike the synthesized encode.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(orientation, forKey: .orientation)
        try container.encode(wrapFocus, forKey: .wrapFocus)
        try container.encode(
            newWindowPlacement,
            forKey: .newWindowPlacement
        )
        try container.encode(appBar, forKey: .appBar)
        if !override.isEmpty {
            try container.encode(override, forKey: .override)
        }
    }
}
