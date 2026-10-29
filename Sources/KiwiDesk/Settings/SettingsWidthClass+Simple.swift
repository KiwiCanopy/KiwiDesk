import CoreGraphics

/// Simple's two columns (#2737 ruling 10): where a panel docks the
/// preview takes one width and the controls the rest, their content
/// capped. Whether it docks is `SettingsPreviewForm`'s, and the
/// column's width is `SettingsView.dockedPanelWidth`'s to answer.
enum SimpleColumns {
    /// The docked preview column's width.
    static let preview: CGFloat = 560
    /// The controls' content cap, so a wide window does not
    /// stretch the rows.
    static let contentCap: CGFloat = 760
}
