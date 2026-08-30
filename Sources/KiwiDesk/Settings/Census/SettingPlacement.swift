/// Placement vocabulary of the settings census (#678).

/// Settings modes: "Simple" and "Power User".
enum SettingsMode: String, CaseIterable, Hashable {
    case simple
    case powerUser
}

/// A Home-level area card in the Settings window.
enum SettingsArea: CaseIterable, Hashable {
    case gapsAndBorders
    case layoutDefaults
    case shortcuts
    case coloursAndMotion
    case bars
    case advancedColours
    case spacesAndLayouts
    case behaviour
    case monitors
    case profiles
    case appRules
    case general

    /// The mode an area first appears in.
    var minimumMode: SettingsMode {
        switch self {
        case .advancedColours, .behaviour, .monitors:
            return .powerUser
        case .layoutDefaults, .gapsAndBorders, .shortcuts,
            .coloursAndMotion, .bars, .spacesAndLayouts,
            .profiles, .appRules, .general:
            return .simple
        }
    }

    /// Effective minimum mode, promoting Monitors to Simple for multi-display.
    func effectiveMinimumMode(
        displayCount: Int
    ) -> SettingsMode {
        if self == .monitors, displayCount >= 2 {
            return .simple
        }
        return minimumMode
    }
}

/// How deep a setting sits within its container.
enum SettingTier: Hashable {
    /// Visible at rest in its container.
    case atRest
    /// Behind the container's "Show more" disclosure or context menu.
    case showMore
    /// Surfaces without disclosure when its configuration exists.
    case immediate
    /// Reachable from Lua without a dedicated GUI row.
    case luaOnly
    /// App-internal storage without a settings surface.
    case internalOnly
    /// Surfaced outside Settings (e.g. onboarding wizard).
    case outsideSettings
}

/// How a row is titled: a static `L()` key or dynamic runtime text.
enum SettingLabel: Hashable {
    case key(String)
    case dynamic
}

/// Localized text for a setting row (`SettingKeyLocaleTests`).
struct SettingRowText: Hashable {
    var label: SettingLabel?
    var captionKey: String?
    var helpKey: String?

    static let none = SettingRowText(
        label: nil,
        captionKey: nil,
        helpKey: nil
    )
    static let dynamic = SettingRowText(
        label: .dynamic,
        captionKey: nil,
        helpKey: nil
    )
    static func text(
        _ labelKey: String,
        caption: String? = nil,
        help: String? = nil
    ) -> SettingRowText {
        SettingRowText(
            label: .key(labelKey),
            captionKey: caption,
            helpKey: help
        )
    }
}

/// Setting location: area card, container, tier, and optional gate.
struct SettingPlacement: Hashable {
    var area: SettingsArea?
    var container: SettingsContainer?
    var tier: SettingTier
    var gate: SettingGate?
    /// True if exempt from container-level gate.
    var exemptFromContainerGate = false

    /// No individual GUI row (#754; see `SettingKey.masterWrites`).
    static let luaOnly = SettingPlacement(
        area: nil,
        container: nil,
        tier: .luaOnly,
        gate: nil
    )
    static let internalOnly = SettingPlacement(
        area: nil,
        container: nil,
        tier: .internalOnly,
        gate: nil
    )
    static let outsideSettings = SettingPlacement(
        area: nil,
        container: nil,
        tier: .outsideSettings,
        gate: nil
    )
    static func row(
        _ area: SettingsArea,
        _ container: SettingsContainer,
        _ tier: SettingTier,
        gate: SettingGate? = nil,
        exemptFromContainerGate: Bool = false
    ) -> SettingPlacement {
        SettingPlacement(
            area: area,
            container: container,
            tier: tier,
            gate: gate,
            exemptFromContainerGate: exemptFromContainerGate
        )
    }
}
