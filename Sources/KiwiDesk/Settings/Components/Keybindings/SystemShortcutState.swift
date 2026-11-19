import KiwiDeskCore

/// What macOS's own shortcuts are doing on this Mac, read once per
/// section render (#1105, #3319): the ones switched off, and the
/// chord each input-source shortcut answers now. A row surface takes
/// it from `\.systemShortcutState`, never a read of its own.
struct SystemShortcutState: Equatable {
    /// The system shortcuts macOS has switched off.
    var disabled: Set<SystemShortcut>
    /// The chord each of macOS's two input-source shortcuts answers
    /// now; absent while macOS has it off.
    var inputSources: [SystemShortcut: KeyCombo]
    /// Whether this Mac tells modifier sides apart (#2601), which
    /// decides whether a row's press is the keyboard tap's.
    var sides = false

    /// macOS's two input-source shortcuts (#3319, #3331).
    static let inputSourceShortcuts: [SystemShortcut] = [
        .inputSourceNext, .inputSourcePrevious,
    ]

    /// Nothing read: no shortcut off, and no input-source chord to
    /// name. A mount outside the section's wiring reads this.
    static let unread = Self(disabled: [], inputSources: [:])

    /// The state `read` answers, an absent entry taking macOS's
    /// shipped default.
    static func live(reading read: (Int) -> SymbolicHotkeyEntry?) -> Self {
        Self(
            disabled: SystemShortcutEnablement.disabled(reading: read),
            inputSources: inputSourceShortcuts.reduce(into: [:]) {
                $0[$1] = $1.answeredChord(reading: read)
            }
        )
    }

    /// The chord of the input-source shortcut other than `taken`
    /// while macOS answers it and no row of any of `config`'s layers
    /// takes it from macOS; nil otherwise, and for a `taken` that is
    /// no input-source shortcut. A row macOS answers beside (#3504)
    /// leaves the chord switching. A row in a layer not active, a Lua
    /// `bind` and a profile's own override row are not told apart:
    /// the first leaves the clause out, the other two are unseen.
    func inputSourceStillSwitching(
        besides taken: SystemShortcut,
        in config: GuiConfig
    ) -> KeyCombo? {
        guard Self.inputSourceShortcuts.contains(taken),
            let other = Self.inputSourceShortcuts.first(where: {
                $0 != taken
            }),
            let chord = inputSources[other]
        else { return nil }
        let taken = config.layers.contains { layer in
            layer.bindings.contains { row in
                KeyCombo.parse(row.combo)?.registered == chord.registered
                    && !sharesWithMacOS(other, row, in: layer.bindings)
            }
        }
        return taken ? nil : chord
    }

    /// Whether `row`, on `shortcut`'s chord, fires beside macOS's
    /// shortcut rather than taking it (`SystemShortcut.answer(on:)`).
    private func sharesWithMacOS(
        _ shortcut: SystemShortcut,
        _ row: KeyBinding,
        in rows: [KeyBinding]
    ) -> Bool {
        guard
            case .systemShortcut(shortcut, let path)? =
                KeybindingConflicts.conflict(
                    for: row,
                    in: rows,
                    distinguishingSides: sides
                )?.target
        else { return false }
        return shortcut.answer(on: path) == .both
    }
}
