import CoreGraphics

/// Simple's two columns (#2737 ruling 10): the preview docks only
/// where `SettingsWidthClass.docksPanel` does, at one width, and
/// the controls take the rest, their content capped.
enum SimpleColumns {
    /// The docked preview column's width.
    static let preview: CGFloat = 560
    /// The controls' content cap, so a wide window does not
    /// stretch the rows.
    static let contentCap: CGFloat = 760
    /// The narrowest controls column the docking width leaves.
    static let minimumControls: CGFloat =
        SettingsWidthClass.panelBreakpoint - preview - 1

    /// The docked preview's width in `width`, nil where it does
    /// not dock — the column and the save pill's centring read
    /// this one answer.
    static func dockedPreview(_ width: SettingsWidthClass) -> CGFloat? {
        width.docksPanel ? preview : nil
    }
}
