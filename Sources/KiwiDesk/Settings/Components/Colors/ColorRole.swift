import KiwiDeskCore

/// The two role groups of Colors & glass (#1857, #2389): each
/// holds one half of both colour-vision pairs.
enum ColorRole: CaseIterable {
    case accent
    case secondAccent

    @MainActor var control: SettingsControl {
        switch self {
        case .accent:
            return SettingsCatalog.colors.colorsAndGlass.children
                .accentGroup
        case .secondAccent:
            return SettingsCatalog.colors.colorsAndGlass.children
                .secondAccentGroup
        }
    }

    @MainActor var caption: String {
        switch self {
        case .accent:
            return L(
                "colors.accent.caption",
                "The active Space, the focus border and the "
                    + "window you drag."
            )
        case .secondAccent:
            return L(
                "colors.second_accent.caption",
                "The focused window on the Space Bar, and where "
                    + "a dragged window lands."
            )
        }
    }

    /// The group's rows, in display order.
    var keys: [SettingKey] {
        switch self {
        case .accent: return ColorsRowOrder.accentRows
        case .secondAccent: return ColorsRowOrder.secondAccentRows
        }
    }

    /// The colour the group is anchored on: its pair's half.
    var anchor: SettingKey {
        switch self {
        case .accent: return .kiwishelf(.activeItemColor)
        case .secondAccent: return .spaceBar(.spaceBarFocusedItemColor)
        }
    }

    /// The group colour's own census row (#1857).
    var paint: SettingKey {
        switch self {
        case .accent: return .colours(.accentPaint)
        case .secondAccent: return .colours(.secondAccentPaint)
        }
    }

    /// Rows whose empty value follows another colour, so a group
    /// colour never writes them (`ColorPaletteKeys.followers`).
    var followers: Set<SettingKey> {
        switch self {
        case .accent: return []
        case .secondAccent:
            return [.spaceBar(.spaceBarFocusedHighlightColor)]
        }
    }
}
