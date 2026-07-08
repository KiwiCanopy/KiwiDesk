import SwiftUI

/// Shared row metrics for the settings tabs: every labeled
/// control row hangs its control off the same leading axis,
/// and every slider readout shares one column width, so
/// controls start and end on one line across sections instead
/// of each row picking its own label width.
enum SettingsMetrics {
    /// The label column in front of sliders, segmented pickers
    /// and dropdowns. Sized for the longest row label in use
    /// ("Mouse resize action") at body size — a narrower
    /// column would truncate it.
    static let labelColumn: CGFloat = 120

    /// The trailing numeric readout of a slider row. Sized for
    /// the widest value in use ("2000 pt").
    static let readoutColumn: CGFloat = 64
}
