import KiwiDeskCore

/// How copy names a screen (#2792, #3502): a twin — a screen whose
/// name another connected screen shares — by its position, every
/// other screen by its own name.
extension ScreenLabel {
    /// Its own name, or its position where another connected
    /// screen shares it: "Twin (left)".
    @MainActor var displayName: String {
        Self.named(name, at: twinPosition)
    }

    /// `name` with its `position` where it has one, macOS's " (n)"
    /// dropped (`Display.twinName`); the one wording of a twin.
    @MainActor static func named(
        _ name: String,
        at position: ScreenNamePosition?
    ) -> String {
        guard let position else { return name }
        let name = Display.twinName(name)
        switch position {
        case .left: return L("screens.shift.name.left", "%1$@ (left)", name)
        case .right:
            return L("screens.shift.name.right", "%1$@ (right)", name)
        case .middle:
            return L("screens.shift.name.middle", "%1$@ (middle)", name)
        case .above:
            return L("screens.shift.name.above", "%1$@ (above)", name)
        case .below:
            return L("screens.shift.name.below", "%1$@ (below)", name)
        }
    }
}
