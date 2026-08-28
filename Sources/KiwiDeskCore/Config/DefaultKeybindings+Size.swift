import Foundation

/// The seeded ⌥⌘ **size** layer (#1075), split from
/// `DefaultKeybindings` at the §2.1 file target: the four rows
/// are short, but the argument for which four keys they are is
/// not, and it is the part a retune has to read.
extension DefaultKeybindings {
    /// The four ⌥⌘ + digit resize rows (#1075): `1`/`2` shrink
    /// and grow WIDTH, `4`/`5` shrink and grow HEIGHT, each by
    /// the configurable `resize.step` (#58).
    ///
    /// Digits rather than arrows because an arrow reads two ways
    /// on a tiled window — "which axis and sign" and "which way
    /// the edge moves" — and which edge is free depends on where
    /// the window sits in the flat array, so the same arrow grows
    /// a right-column window and shrinks a left-column one. No
    /// relabelling fixes that; the arrow shape creates it.
    ///
    /// Within a pair the HIGHER digit grows, and the pairs form a
    /// 2×2 block on a numeric keypad — `4`/`5` sit directly above
    /// `1`/`2`, so the pair that is higher drives the dimension
    /// that grows upward. That block is the only place a keyboard
    /// encodes a second axis without using arrows, and it is why
    /// this binds digits at all; **#1074 is what will make those
    /// keypad keys reach these rows**, and until it lands only
    /// the number row fires them.
    ///
    /// `5`/`6` and `2`/`3`+`5`/`6` were both rejected: touch
    /// typing splits the number row between `5` and `6`, so any
    /// pair spanning them straddles the hand boundary.
    ///
    /// The pairs are also SEPARATED — `3` sits between them on
    /// the number row — so a mistimed reach for "grow width"
    /// cannot land on "shrink height" (owner, 2026-08-28). Keep
    /// that gap when retuning: two adjoining pairs would put the
    /// two axes' nearest keys against each other.
    ///
    /// **The digits are measured, not assumed.** `⌥⌘8` is macOS's
    /// Zoom toggle and `⌥⌘-` / `⌥⌘=` are Zoom out / in
    /// (`com.apple.symbolichotkeys` ids 15/19/17, read
    /// 2026-08-28), so an earlier `4`/`5`+`7`/`8` draft would have
    /// died for any user with Zoom's keyboard shortcuts on.
    /// `SystemShortcuts.map` carries them, and
    /// `SizeLayerSeedTests` holds every seeded row against it.
    /// Why ⌥⌘ is available at all, given #270 rejected it, is
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
