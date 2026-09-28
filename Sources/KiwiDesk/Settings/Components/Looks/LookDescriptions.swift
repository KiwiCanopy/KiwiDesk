import KiwiDeskCore

/// The bundled looks' one-line descriptions (#1684): our own
/// names on the cards, the reference only here (owner ruling
/// 2026-09-26). The references are proper names, interpolated as
/// values so every locale can translate the frame around them.
/// Keyed by the bundled name, which is not localized — like a
/// palette's (`LookDescriptionsTests` covers every bundled name).
enum LookDescriptions {
    /// The caption under a bundled look's card, or nil: what the
    /// look does, then what it resembles — the picture is too
    /// small to carry the first half on its own (owner ruling
    /// 2026-09-28, #1720).
    @MainActor static func caption(for name: String) -> String? {
        switch name {
        case LookCatalog.defaultName:
            return L(
                "looks.description.glass",
                "KiwiDesk's own look, in Liquid Glass"
            )
        case "Taskbar":
            return L(
                "looks.description.taskbar",
                "Bottom bar, like %1$@",
                "Windows 11"
            )
        case "Classic":
            return L(
                "looks.description.classic",
                "Thin and flat, like %1$@",
                "Mac OS 9"
            )
        case "Tiler":
            return L(
                "looks.description.tiler",
                "Boxed and monospaced, like %1$@",
                "Hyprland"
            )
        case "Pill":
            return L(
                "looks.description.pill",
                "Rounded and floating, like %1$@",
                "Barik"
            )
        case "Bloom":
            return L(
                "looks.description.bloom",
                "Soft, with a floating dock, like %1$@",
                "iPadOS"
            )
        default:
            return nil
        }
    }
}
