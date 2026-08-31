import CoreGraphics
import Foundation

/// Monocle layout tuning parameters (`AppBarStyle`, `AppBarHosting`).
public struct MonocleParams: Sendable, Equatable, AppBarHosting {
    /// Focus navigation axis and indicator bar placement.
    public enum Orientation: String, Sendable, Codable, CaseIterable {
        case horizontal
        case vertical
    }

    /// Mechanism for hiding unfocused monocle members (#677, #881).
    public enum HideStyle: String, Sendable, Codable, CaseIterable {
        case stack
        case park
    }

    public var orientation: Orientation = .horizontal
    public var hideStyle: HideStyle = .stack
    /// Whether focus navigation wraps at cycle ends (#168).
    public var wrapFocus = false
    /// Placement for newly spawned windows (`SpawnPlacement`).
    public var newWindowPlacement: SpawnPlacement = .first
    public var appBar = LayoutAppBar()
    /// Per-space overrides (`TilingSettings.resolvedMonocle(for:)`).
    public var override: [SpaceID: MonocleOverride] = [:]

    public init() {}
}

// MARK: - Codable

extension MonocleParams: Codable {
    private enum CodingKeys: String, CodingKey {
        case orientation
        case hideStyle = "hide_style"
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
        hideStyle =
            try container.decodeIfPresent(
                HideStyle.self,
                forKey: .hideStyle
            ) ?? defaults.hideStyle
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

    /// Encodes monocle parameters keeping sparse override map structure.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(orientation, forKey: .orientation)
        try container.encode(hideStyle, forKey: .hideStyle)
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
