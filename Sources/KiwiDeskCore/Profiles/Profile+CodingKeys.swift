import Foundation

/// The profile file's keys.
extension Profile {
    enum CodingKeys: String, CodingKey {
        case format
        case id
        case name
        case monitorSets = "monitor_sets"
        case dormantMonitorCount = "monitor_count"
        case mainSpaces = "main_spaces"
        case isDefault = "default"
        case isStarterSetup = "starter_setup"
        case spaces
        case fallbackSpace = "fallback_space"
        case spaceModes = "space_modes"
        case settings
        case savedAt = "saved_at"
        case layers
        case appRules = "app_rules"
        case floatRules = "float_rules"
        case ignoreRules = "ignore_rules"
        case scrollGesture = "scroll_gesture"
        case spaceHistory = "space_history"
        case modeCycle = "mode_cycle"
        case focusWrap = "focus_wrap"
        case floatAutomatically = "float_automatically"
        case tileRules = "tile_rules"
        case look
        case lensReach = "lens_reach"
    }
}

extension Profile {
    /// All entries must share one `monitors` length — the first
    /// entry's length is canonical, mismatched entries dropped.
    static func sanitized(_ sets: [MonitorSet]) -> [MonitorSet] {
        guard let canonical = sets.first?.monitors.count else {
            return []
        }
        return sets.filter { $0.monitors.count == canonical }
    }
}
