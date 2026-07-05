import KiwiDeskCore

/// Best-practice starting points offered on the Presets tab.
/// A preset rewrites the tunable settings but keeps the user's
/// keybindings, app rules, and profile bindings intact.
enum ConfigPreset: String, CaseIterable, Identifiable {
    case developer
    case minimalist
    case stacker

    var id: String { rawValue }

    var title: String {
        switch self {
        case .developer: return "Developer"
        case .minimalist: return "Minimalist"
        case .stacker: return "Stacker"
        }
    }

    var summary: String {
        switch self {
        case .developer:
            return "BSP tiling, tight 8 pt gaps, master-friendly."
        case .minimalist:
            return "Generous 20 pt gaps, centered scrolling."
        case .stacker:
            return "Stack layout with a wide master column."
        }
    }

    /// Produces a config from `base`, replacing only the visual
    /// tuning (gaps, min size, per-layout params, default mode).
    func config(basedOn base: GuiConfig) -> GuiConfig {
        var next = base
        var settings = TilingSettings()
        switch self {
        case .developer:
            settings.gapsGlobal = .uniform(8)
            settings.minWindowSize = 300
            settings.bsp.strategy = .shortestSide
            next.spaceModes = [:]
        case .minimalist:
            settings.gapsGlobal = .uniform(20)
            settings.scrolling.anchor = .center
            next.spaceModes = [SpaceID(1): .scrolling]
        case .stacker:
            settings.gapsGlobal = .uniform(10)
            settings.stack.masterCount = 1
            settings.stack.masterRatio = 0.62
            next.spaceModes = [SpaceID(1): .stack]
        }
        next.settings = settings
        return next
    }
}
