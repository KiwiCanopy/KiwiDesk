import SwiftUI

/// Shared row metrics for the settings tabs: every labeled
/// control row hangs its control off the same leading axis,
/// and every slider readout shares one column width, so
/// controls start and end on one line across sections instead
/// of each row picking its own label width.
enum SettingsMetrics {
    /// The label column in front of sliders, segmented pickers
    /// and dropdowns. The longest row label in use ("Mouse
    /// resize action") measures ~121 pt at body size — 128
    /// keeps headroom so a font-metric change can't silently
    /// wrap it.
    static let labelColumn: CGFloat = 128

    /// The label column inside `OverrideChrome`, whose leading
    /// checkbox prefixes every row with 8 pt padding + ~18 pt
    /// checkbox + 8 pt spacing (34 pt): shrinking the label by
    /// that prefix lands the override row's control on the
    /// same axis as the plain rows. The discount means a label
    /// that fits `labelColumn` can still wrap here — override
    /// labels must measure under ~84 pt at body size (it bit
    /// "Focused anchor" at 97 pt, shortened to "Focus
    /// anchor").
    static let overrideLabelColumn: CGFloat = labelColumn - 34

    /// The trailing numeric readout of a slider row. Sized for
    /// the widest value in use ("2000 pt").
    static let readoutColumn: CGFloat = 64

    /// `HexColorField`'s label column. The color fields live
    /// in their own two-column grid, deliberately NOT on the
    /// shared row axis (120-ish would misalign the grid's
    /// second column) — don't "fix" them onto `labelColumn`.
    static let colorLabelColumn: CGFloat = 140
}
