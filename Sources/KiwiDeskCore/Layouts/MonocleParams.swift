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
    public var appBar = LayoutAppBar()

    public init() {}

    /// AppBarHosting: monocle's bar axis follows its orientation.
    public var barAxisIsHorizontal: Bool {
        orientation == .horizontal
    }
}

// MARK: - Codable

extension MonocleParams: Codable {
    private enum CodingKeys: String, CodingKey {
        case orientation
        case appBar = "app_bar"
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
        appBar =
            try container.decodeIfPresent(
                LayoutAppBar.self,
                forKey: .appBar
            ) ?? defaults.appBar
    }
}
