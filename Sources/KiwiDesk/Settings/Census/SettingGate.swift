/// Settings census gate vocabulary (#678).

/// Runtime condition gating row availability or presence (#342, #390, #578,
/// #1071).
enum SettingRuntimeGate: Hashable {
    /// The gaps master slider reads "mixed" while the per-edge values differ.
    case perEdgeValuesDiffer
    /// A stored profile is being edited, so global settings are locked.
    case editingStoredProfile
    /// Presets apply only when connected screen count matches.
    case screenCountMismatch
    /// Login item follows SMAppService status (#342).
    case loginItemServiceStatus
    /// LaunchAgent service is already loaded (#1071).
    case autoStartServiceLoaded
    /// Space reset is inert when no overrides exist.
    case spaceHasNoOverrides
    /// macOS Reduce Motion greys animations card.
    case reduceMotion
    /// Space pinned to a disconnected monitor.
    case orphanPinsExist
    /// Stored profile edited while monitors are disconnected.
    case monitorsDisconnected
    /// Palettes that carry neon Glow pairing (#578).
    case paletteGlowPairing
    /// Unadopted shortcuts present in init.lua.
    case luaImportAvailable
    /// Restore Defaults appears when unseeded defaults exist.
    case defaultsToRestore
    /// Non-default layer exists in configuration.
    case layersExist
    /// Liquid Glass unavailable on pre-macOS 26 (#390).
    case liquidGlassUnavailable
}

/// Gating specification for disabled or conditionally surfaced setting rows
/// (#406).
enum SettingGate: Hashable {
    case setting(SettingKey)
    case anyOf([SettingKey])
    case runtime(SettingRuntimeGate)
    /// Row is inert while any of these conditions holds.
    case runtimeAnyOf([SettingRuntimeGate])

    /// The setting rows this gate reads.
    var settings: [SettingKey] {
        switch self {
        case .setting(let key): return [key]
        case .anyOf(let keys): return keys
        case .runtime, .runtimeAnyOf: return []
        }
    }

    /// The runtime conditions this gate names.
    var runtimeConditions: [SettingRuntimeGate] {
        switch self {
        case .setting, .anyOf: return []
        case .runtime(let condition): return [condition]
        case .runtimeAnyOf(let conditions): return conditions
        }
    }
}
