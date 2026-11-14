import KiwiDeskCore

/// What macOS's own shortcuts are doing on this Mac, read once per
/// section render (#1105, #3319): the ones switched off, and the
/// chord of the other input-source shortcut while it is on. A row
/// surface takes it from `\.systemShortcutState`, never a read of
/// its own; an array literal names the switched-off set alone.
struct SystemShortcutState: Equatable, ExpressibleByArrayLiteral {
    /// The system shortcuts macOS has switched off.
    var disabled: Set<SystemShortcut>
    /// The chord "Select the previous input source" answers now;
    /// nil while macOS has it off.
    var previousInputSource: KeyCombo?

    init(disabled: Set<SystemShortcut>, previousInputSource: KeyCombo?) {
        self.disabled = disabled
        self.previousInputSource = previousInputSource
    }

    init(arrayLiteral elements: SystemShortcut...) {
        self.init(disabled: Set(elements), previousInputSource: nil)
    }

    /// The state `read` answers, an absent entry taking macOS's
    /// shipped default.
    static func live(reading read: (Int) -> SymbolicHotkeyEntry?) -> Self {
        let other = SymbolicHotkeys.previousInputSource
        let entry = read(other.id)
        return Self(
            disabled: SystemShortcutEnablement.disabled(
                reading: { read($0)?.enabled }
            ),
            previousInputSource: entry?.enabled ?? true
                ? entry?.combo ?? other.chord : nil
        )
    }

    /// The chord of the other input-source shortcut while macOS
    /// answers it and no row of `config` is bound to it; nil
    /// otherwise.
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
