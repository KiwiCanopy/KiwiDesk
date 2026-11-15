import KiwiDeskCore

/// The draft's rule half after a rule write (#1393): adopted as
/// clean where it landed, dropped where it did not.
extension SettingsModel {
    /// Takes a rule half that landed as the draft's baseline, so
    /// only what did not land stays unsaved.
    func adoptRuleHalf() {
        suppressDirty = true
        cleanConfig.appRules = config.appRules
        cleanConfig.titledAppRules = config.titledAppRules
        cleanConfig.floatRules = config.floatRules
        cleanConfig.scrollGesture = config.scrollGesture
        cleanConfig.gesture = config.gesture
        cleanConfig.spaceHistory = config.spaceHistory
        cleanConfig.modeCycle = config.modeCycle
        cleanConfig.focusWrap = config.focusWrap
        cleanConfig.tileRules = config.tileRules
        cleanConfig.floatAutomatically = config.floatAutomatically
        cleanConfig.settings.tiling = config.settings.tiling
        // Not the layers: a stored page's own shortcut diff is the
        // tiling write's, which is what failed.
        ruleReachStored = core.ruleReachSnapshot()
        reachEdits = RuleReachEdits()
        suppressDirty = false
        recomputeDirty()
    }

    /// Drops the draft's rule half, so a globals write after a
    /// failed or refused rule write carries the stored rules.
    func dropRuleHalf() {
        config.appRules = cleanConfig.appRules
        config.titledAppRules = cleanConfig.titledAppRules
        config.floatRules = cleanConfig.floatRules
        config.layers = cleanConfig.layers
        // Drafted beside the layers it moves (#1870): never kept
        // without them.
        config.shortcutBase = cleanConfig.shortcutBase
        config.scrollGesture = cleanConfig.scrollGesture
        config.gesture = cleanConfig.gesture
        config.spaceHistory = cleanConfig.spaceHistory
        config.modeCycle = cleanConfig.modeCycle
        config.focusWrap = cleanConfig.focusWrap
        config.tileRules = cleanConfig.tileRules
        config.floatAutomatically = cleanConfig.floatAutomatically
        config.settings.tiling = cleanConfig.settings.tiling
        reachEdits = RuleReachEdits()
    }
}
