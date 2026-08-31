import Foundation

/// Default size layer keybindings (#1075).
extension DefaultKeybindings {
    /// Seeded ⌥⌘ + digit resize keybindings (`resize.step`, `KeypadKeys`,
    /// `SystemShortcuts.map`, `SizeLayerSeedTests`, #58, #270, #1074, #1075).
    static func resizeRows(step: Int) -> [KeyBinding] {
        [
            KeyBinding(
                combo: "option+command+2",
                lua: "KiwiDesk.resize(\"x\", \(step))",
                kind: .navigation,
                label: "Grow width"
            ),
            KeyBinding(
                combo: "option+command+1",
                lua: "KiwiDesk.resize(\"x\", -\(step))",
                kind: .navigation,
                label: "Shrink width"
            ),
            KeyBinding(
                combo: "option+command+5",
                lua: "KiwiDesk.resize(\"y\", \(step))",
                kind: .navigation,
                label: "Grow height"
            ),
            KeyBinding(
                combo: "option+command+4",
                lua: "KiwiDesk.resize(\"y\", -\(step))",
                kind: .navigation,
                label: "Shrink height"
            ),
        ]
    }
}
