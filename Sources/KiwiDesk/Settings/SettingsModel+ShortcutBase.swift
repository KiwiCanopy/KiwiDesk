import KiwiDeskCore

/// The "Shortcuts use" switch's model half (#2460): the switch is
/// staged into the draft like any recorded chord — Save registers it
/// (input-and-animation.md ▸ written only from saved files) — and
/// the rows it left on `⌃⌥` are read off the draft and the stored
/// profiles, each with its reason.
extension SettingsModel {
    /// Moves every row the mapping covers onto `base` and sets the
    /// base, in one draft write (`ShortcutBaseSwitch`).
    func setShortcutBase(_ base: ShortcutBase) {
        guard base != config.shortcutBase else { return }
        ShortcutBaseSwitch.apply(base, to: &config)
    }

    /// Whether the draft holds anything on Hyper — a row or the
    /// base — which keeps the Hyper card in Simple with no key set,
    /// since config presence expands Simple (gui.md).
    var draftUsesHyper: Bool {
        config.shortcutBase == .hyper
            || config.layers.contains {
                $0.bindings.contains {
                    KeyCombo.parse($0.combo)?.modifiers.contains(.hyper)
                        == true
                }
            }
    }

    /// The rows still on `⌃⌥` while the base is `✦`, default layer
    /// first, then the other profiles' own rows; empty on `⌃⌥`.
    var rowsLeftOnStandard: [ShortcutBaseLeftRow] {
        guard config.shortcutBase == .hyper else { return [] }
        let seeded = seededChords
        var rows: [ShortcutBaseLeftRow] = []
        for layer in config.layers {
            let kept = ShortcutBaseSwitch.kept(layer.bindings, onto: .hyper)
            for row in layer.bindings where movesToHyper(row) {
                let reason: ShortcutBaseLeftRow.Reason
                if let hold = kept.first(where: { $0.row == row }) {
                    reason = .taken(
                        chord: ShortcutBaseWords.chord(hold.target),
                        by: KeybindingCatalog.localizedName(
                            of: hold.holder,
                            config: config
                        )
                    )
                } else if seeded[row.lua] == row.combo {
                    reason = .predates
                } else {
                    reason = .ownChoice
                }
                rows.append(left(row, layer: layer.name, reason: reason))
            }
        }
        for (profile, override) in otherProfileOverrides {
            for layer in override.layers {
                for row in layer.bindings where movesToHyper(row) {
                    rows.append(
                        left(row, layer: layer.name, reason: .profile(profile))
                    )
                }
            }
        }
        return rows
    }

    private func movesToHyper(_ row: KeyBinding) -> Bool {
        KeyCombo.parse(row.combo).flatMap {
            ShortcutBase.moved($0, to: .hyper)
        } != nil
    }

    private func left(
        _ row: KeyBinding,
        layer: String,
        reason: ShortcutBaseLeftRow.Reason
    ) -> ShortcutBaseLeftRow {
        ShortcutBaseLeftRow(
            id: "\(layer)␟\(row.lua)␟\(reason.id)",
            name: KeybindingCatalog.localizedName(of: row, config: config),
            chord: ShortcutBaseWords.chord(row.combo),
            reason: reason
        )
    }

    /// The seed's own `⌃⌥` chord per action, the Desktop tier
    /// included: a row still on it predates the switch.
    private var seededChords: [String: String] {
        let seed =
            DefaultKeybindings.bindings(
                spaces: config.spaces,
                resizeStep: Int(config.settings.resizeStep),
                base: .standard
            )
            + (1...DefaultKeybindings.digitCapacity).compactMap {
                DefaultKeybindings.desktopRow($0, base: .standard)
            }
        return Dictionary(
            seed.map { ($0.lua, $0.combo) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// Every stored profile's own layer rows but the page's, by
    /// name: the switch reaches the shared keymap and the loaded
    /// profile alone.
    private var otherProfileOverrides: [(String, KeyLayerOverride)] {
        guard let stored = ruleReachStored else { return [] }
        return stored.storedKeyOverrides
            .filter { $0.key != reachPage }
            .sorted { $0.key < $1.key }
    }
}

/// One row the switch left on `⌃⌥`, named for the list under it.
struct ShortcutBaseLeftRow: Identifiable, Equatable {
    enum Reason: Equatable {
        /// On the seed's own chord: the row predates the switch.
        case predates
        /// The `✦` chord it would take is another row's.
        case taken(chord: String, by: String)
        /// On a `⌃⌥` chord of the user's own.
        case ownChoice
        /// Another profile's own row, which the switch never moves.
        case profile(String)

        var id: String {
            switch self {
            case .predates: "predates"
            case .taken: "taken"
            case .ownChoice: "own"
            case .profile(let name): "profile:\(name)"
            }
        }
    }

    let id: String
    let name: String
    let chord: String
    let reason: Reason
}
