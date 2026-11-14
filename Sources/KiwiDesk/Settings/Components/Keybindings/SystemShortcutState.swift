import KiwiDeskCore

/// What macOS's own shortcuts are doing on this Mac, read once per
/// section render (#1105, #3319): the ones switched off, and the
/// chord of the other input-source shortcut while it is on. A row
/// surface takes it from `\.systemShortcutState`, never a read of
/// its own.
struct SystemShortcutState: Equatable {
    /// The system shortcuts macOS has switched off.
    var disabled: Set<SystemShortcut>
    /// The chord "Select the previous input source" answers now;
    /// nil while macOS has it off.
    var previousInputSource: KeyCombo?

    /// Nothing read: no shortcut off, and no other input-source
    /// chord to name. A mount outside the section's wiring reads
    /// this.
    static let unread = Self(disabled: [], previousInputSource: nil)

    /// The state `read` answers, an absent entry taking macOS's
    /// shipped default.
    static func live(reading read: (Int) -> SymbolicHotkeyEntry?) -> Self {
        Self(
            disabled: SystemShortcutEnablement.disabled(
                reading: { read($0)?.enabled }
            ),
            previousInputSource: SymbolicHotkeys.answeredChord(
                of: SymbolicHotkeys.previousInputSource,
                reading: read
            )
        )
    }

    /// The chord of the other input-source shortcut while macOS
    /// answers it and no row of any of `config`'s layers is bound to
    /// it; nil otherwise. A row in a layer not active, a Lua `bind`
    /// and a profile's own override row are not told apart: the
    /// first leaves the clause out, the other two are unseen.
    func inputSourceStillSwitching(in config: GuiConfig) -> KeyCombo? {
        guard let chord = previousInputSource else { return nil }
        let bound = config.layers.contains { layer in
            layer.bindings.contains {
                KeyCombo.parse($0.combo)?.registered == chord.registered
            }
        }
        return bound ? nil : chord
    }
}
