import CoreGraphics
import KiwiDeskCore

/// The per-layout override rows' value formatters and row
/// shape, split from `SettingsValueReadout+LayoutAppBar.swift`
/// so neither file crosses the size ceiling (the
/// `SettingKey+BordersText` shape). Internal rather than
/// private because the switch consuming them lives in that
/// sibling file; the `layoutBar` prefix keeps them scoped to
/// this key slice.
///
/// Every formatter here takes the OPTIONAL stored override:
/// nil is "inherit the global style", shown as the core's
/// `unset` "—", so a gained override reads "— → 44 pt".
extension SettingsValueReadout {
    /// One row, labelled "Monocle · Thickness": the layout's
    /// display name plus the global twin's census label, since
    /// the override keys themselves are surfaceless
    /// (GUI_REMOVED) and carry no row text of their own.
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

    /// The label the Bars editor's own option list renders for
    /// a set override; the fallback is unreachable while those
    /// lists stay exhaustive (their own docs hold them to it).
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

    /// `0` is the auto sentinel on the size sliders, exactly as
    /// on the global style — an override CAN pin a layout back
    /// to auto, so it reads "Automatic" rather than "0 pt".
    static func layoutBarAutoPoints(
        _ value: CGFloat?
    ) -> String {
        guard let value else { return unset }
        return value == 0
            ? L("settings.readout.auto", "Automatic")
            : points(value)
    }

    /// Corner roundness is stored 0–100; the GUI row reads %.
    static func layoutBarRoundness(
        _ value: CGFloat?
    ) -> String {
        guard let value else { return unset }
        return percent(Double(value) / 100)
    }

    /// A bare number, for the Lua-only dim factor (no GUI row,
    /// so no unit to borrow — the stored fraction shows as is).
    static func layoutBarNumber(_ value: CGFloat?) -> String {
        value.map(trimmed) ?? unset
    }

    /// A set override's hex, shown verbatim: uppercased,
    /// leading "#".
    static func layoutBarHex(_ raw: String?) -> String {
        guard let raw else { return unset }
        let digits =
            raw.hasPrefix("#") ? String(raw.dropFirst()) : raw
        return "#" + digits.uppercased()
    }
}
