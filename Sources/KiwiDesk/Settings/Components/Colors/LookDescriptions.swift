import KiwiDeskCore

/// The bundled looks' one-line descriptions (#1684): our own
/// names on the cards, the reference only here (owner ruling
/// 2026-09-26). Keyed by the bundled name, which is not localized
/// — like a palette's.
enum LookDescriptions {
    /// The caption under a bundled look's card, or nil.
    @MainActor static func caption(for name: String) -> String? {
        switch name {
        case LookCatalog.defaultName:
            return L("looks.description.glass", "KiwiDesk's default")
        case "Taskbar":
            return L(
                "looks.description.taskbar",
                "In the style of Windows 11"
            )
        case "Classic":
            return L(
                "looks.description.classic",
                "In the style of the classic Mac OS"
            )
        case "Tiler":
            return L(
                "looks.description.tiler",
                "In the style of Hyprland and Omarchy"
            )
        case "Pill":
            return L("looks.description.pill", "In the style of Barik")
        default:
            return nil
        }
    }
}
