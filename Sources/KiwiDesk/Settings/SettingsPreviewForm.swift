/// Responsive display form for live previews
/// (`SettingsResponsiveOrderTests`, #678 17a).
enum SettingsPreviewForm: String, CaseIterable, Sendable {
    /// Dedicated side column — the only form taking layout space,
    /// so the only one the save pill's centring offset answers to.
    case docked
    /// Floating card overlay.
    case floating
    /// Collapsed state showing button offer.
    case offer

    /// Resolves preview form; `shown` is whether the user opened
    /// the card this mount. Below the docking width the card waits
    /// to be opened (#1854).
    static func at(
        _ width: SettingsWidthClass,
        shown: Bool
    ) -> SettingsPreviewForm {
        if width.docksPanel { return .docked }
        return shown ? .floating : .offer
    }
}
