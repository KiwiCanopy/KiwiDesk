import Foundation

/// Default size layer keybindings (#1075).
extension DefaultKeybindings {
    /// Seeded ⌥⌘ + digit resize rows (#1075): `1`/`2` width,
    /// `4`/`5` height, by `resize.step` (#58). Digits, not arrows:
    /// an arrow reads two ways on a tiled window, and which edge
    /// is free depends on the slot. Within a pair the HIGHER digit
    /// grows, and the pairs form the keypad's 2×2 block — #1074's
    /// aliasing makes those keypad keys reach these rows
    /// (`KeypadKeys`). The pairs are SEPARATED on the number row
    /// (owner 2026-08-28): keep that gap when retuning, or the two
    /// axes' nearest keys sit adjacent. The digits are MEASURED,
    /// not assumed — `⌥⌘8` is macOS Zoom toggle
    /// (`SystemShortcuts.map`; `SizeLayerSeedTests` holds every
    /// seeded row against it). Why ⌥⌘ is available despite #270 is
    /// argued in `docs/design-decisions.md`.
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
