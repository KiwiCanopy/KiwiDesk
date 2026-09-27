import KiwiDeskCore

extension SettingPlacement {
    /// Hidden on this Mac: the row needs Liquid Glass and the
    /// platform draws none — an OS-capability HIDE, never a grey
    /// (#390). The one reading both the search index and the Glass
    /// card take.
    var hiddenWithoutGlass: Bool {
        (gate?.runtimeConditions.contains(.liquidGlassUnavailable)
            ?? false) && !AppBarStyle.glassAvailable
    }
}
