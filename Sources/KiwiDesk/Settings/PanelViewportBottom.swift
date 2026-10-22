import SwiftUI

private struct PanelViewportBottomKey: EnvironmentKey {
    static let defaultValue: CGFloat? = nil
}

extension EnvironmentValues {
    /// The global bottom edge of the panel's visible scroll area,
    /// so a preview's overlay knows how far it may draw (#2532);
    /// nil outside the panel.
    var panelViewportBottom: CGFloat? {
        get { self[PanelViewportBottomKey.self] }
        set { self[PanelViewportBottomKey.self] = newValue }
    }
}
