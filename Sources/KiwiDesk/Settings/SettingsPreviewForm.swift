/// Responsive display form for live previews
/// (`SettingsResponsiveOrderTests`, #678 17a).
enum SettingsPreviewForm: String, CaseIterable, Sendable {
    /// Dedicated side column.
    case docked
    /// Floating card overlay.
    case floating
    /// Collapsed state showing button offer.
    case offer

    /// Resolves preview form for width class and visibility state.
    static func at(
        _ width: SettingsWidthClass,
        shown: Bool?
    ) -> SettingsPreviewForm {
        if width.docksPanel { return .docked }
        return (shown ?? width.floatsPreviewByDefault)
            ? .floating : .offer
    }
}
