import KiwiDeskCore

/// The bundled looks' one-line descriptions (#1684): our own
/// names on the cards, the reference only here (owner ruling
/// 2026-09-26). The references are proper names, interpolated as
/// values so every locale can translate the frame around them.
/// Keyed by the bundled name, which is not localized — like a
/// palette's (`LookDescriptionsTests` covers every bundled name).
enum LookDescriptions {
    /// What each bundled look is in the style of; Glass is ours.
    static let references: [String: [String]] = [
        "Taskbar": ["Windows 11"],
        "Classic": ["Mac OS 9"],
        "Tiler": ["Hyprland", "Omarchy"],
        "Pill": ["Barik"],
    ]

    /// The caption under a bundled look's card, or nil.
    @MainActor static func caption(for name: String) -> String? {
        if name == LookCatalog.defaultName {
            return L("looks.description.glass", "KiwiDesk's default")
        }
        switch references[name] ?? [] {
        case let names where names.count == 1:
            return L(
                "looks.description.style_of",
                "In the style of %1$@",
                names[0]
            )
        case let names where names.count == 2:
            return L(
                "looks.description.style_of_pair",
                "In the style of %1$@ and %2$@",
                names[0],
                names[1]
            )
        default:
            return nil
        }
    }
}
