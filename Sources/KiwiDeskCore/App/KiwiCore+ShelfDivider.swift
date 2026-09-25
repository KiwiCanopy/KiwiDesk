import CoreGraphics

/// The section divider's drag (#1517, ruling 15).
extension KiwiCore {
    /// Writes the Space Bar minimum the divider reached. A step
    /// re-lays the bars alone; the release goes through `execute`,
    /// the settings-apply door Lua and the CLI take, and retiles
    /// once. Both take `KiwiShelfCommandSetting`'s own clamp.
    func dragShelfMinimum(_ percent: CGFloat, committed: Bool) {
        guard committed else {
            KiwiShelfCommandSetting.minimum(percent)
                .apply(to: &tiler.settings.kiwishelf)
            updateBars()
            return
        }
        execute("kiwishelf.set_minimum", args: [.number(Double(percent))])
    }
}
