import CoreGraphics
import KiwiDeskCore

/// Value formatters for layout App Bar overrides in diff readout
/// (`SettingsValueReadout`).
extension SettingsValueReadout {
    /// Formats diff row for per-layout App Bar override key.
    static func layoutBarRow(
        _ census: SettingKey,
        _ mode: LayoutMode,
        _ twin: AppBarKey,
        _ old: String,
        _ new: String
    ) -> [SettingsDiffRow] {
        [
            .change(
                census,
                label: instanceLabel(
                    mode.displayName,
                    label(for: .appBar(twin))
                ),
                old: old,
                new: new
            )
        ]
    }

    /// Resolves override option label from options list or falls back to unset
    /// dash.
    static func layoutBarChoice<T: Equatable>(
        _ value: T?,
        _ options: [(T, String)]
    ) -> String {
        guard let value else { return unset }
        return options.first { $0.0 == value }?.1
            ?? String(describing: value)
    }

    static func layoutBarOnOff(_ value: Bool?) -> String {
        value.map(onOff) ?? unset
    }

    static func layoutBarPoints(_ value: CGFloat?) -> String {
        value.map(points) ?? unset
    }

    /// Formats points or "Automatic" for 0 sentinel (`autoPoints`).
    static func layoutBarAutoPoints(
        _ value: CGFloat?
    ) -> String {
        value.map(autoPoints) ?? unset
    }

    /// Formats 0–100 corner roundness as percentage string.
    static func layoutBarRoundness(
        _ value: CGFloat?
    ) -> String {
        guard let value else { return unset }
        return percent(Double(value) / 100)
    }

    /// Formats bare numeric value for Lua-only overrides.
    static func layoutBarNumber(_ value: CGFloat?) -> String {
        value.map(trimmed) ?? unset
    }

    /// Formats whole integer count or unset dash.
    static func layoutBarCount(_ value: Int?) -> String {
        value.map { trimmed(Double($0)) } ?? unset
    }

    /// Formats hex color string via hexDisplay or returns unset dash.
    static func layoutBarHex(_ raw: String?) -> String {
        raw.map(hexDisplay) ?? unset
    }
}
