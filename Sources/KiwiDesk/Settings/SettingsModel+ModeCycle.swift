import KiwiDeskCore

/// The layout cycle list's edits (#453): every one keeps the list
/// a cycle `ModeCycle.isValid` accepts, so the row can never
/// stage a draft the decoder would refuse.
extension SettingsModel {
    /// The layouts not in `cycle`, in the Layout menu's order.
    static func cycleAddable(besides cycle: [LayoutMode]) -> [LayoutMode] {
        LayoutMode.allCases.filter { !cycle.contains($0) }
    }

    /// Whether a layout can leave the cycle: never below two.
    var modeCycleCanRemove: Bool {
        config.modeCycle.count > ModeCycle.minimumCount
    }

    /// Appends `mode` at the end of the cycle.
    func addCycleMode(_ mode: LayoutMode) {
        guard !config.modeCycle.contains(mode) else { return }
        config.modeCycle.append(mode)
    }

    /// Takes `mode` out of the cycle, refused at two.
    func removeCycleMode(_ mode: LayoutMode) {
        guard modeCycleCanRemove,
            let index = config.modeCycle.firstIndex(of: mode)
        else { return }
        config.modeCycle.remove(at: index)
    }

    /// Moves `mode` one step toward the top (−1) or bottom (+1).
    func stepCycleMode(_ mode: LayoutMode, by step: Int) {
        guard let from = config.modeCycle.firstIndex(of: mode) else {
            return
        }
        let to = from + step
        guard config.modeCycle.indices.contains(to) else { return }
        config.modeCycle.swapAt(from, to)
    }

    /// Writes a whole reordered cycle, the drag's commit; ignored
    /// unless it holds the same layouts.
    func reorderCycle(_ order: [LayoutMode]) {
        guard order != config.modeCycle,
            Set(order) == Set(config.modeCycle),
            ModeCycle.isValid(order)
        else { return }
        config.modeCycle = order
    }
}
