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
    /// base — which holds the Modifier keys card open on arrival
    /// with no key set (config presence, gui.md).
    var draftUsesHyper: Bool {
        config.shortcutBase == .hyper
            || config.layers.contains {
                $0.bindings.contains {
                    KeyCombo.parse($0.combo)?.modifiers.contains(.hyper)
                        == true
                }
            }
    }

    /// The rows still on `⌃⌥` while the base is `✦`, the page's
    /// layers first, then the shared rows this page does not draw,
    /// then the other profiles' own rows; empty on `⌃⌥`. A shared
    /// row the page leaves out moves with the rest, its tombstone
    /// with it (`moveShortcutBase`), so it is listed only where it
    /// stayed for a reason the page's own rows could have.
    var rowsLeftOnStandard: [ShortcutBaseLeftRow] {
        guard config.shortcutBase == .hyper else { return [] }
        let seeded = seededChords
        var rows: [ShortcutBaseLeftRow] = []
        for layer in config.layers {
            rows += leftRows(of: layer, seeded: seeded) { _ in true }
        }
        rows += hiddenSharedRows(seeded: seeded)
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

    /// `layer`'s rows `listed` names that are still on `⌃⌥`, each
    /// with its reason.
    private func leftRows(
        of layer: KeyLayer,
        seeded: [String: Set<String>],
        listed: (KeyBinding) -> Bool
    ) -> [ShortcutBaseLeftRow] {
        let kept = ShortcutBaseSwitch.kept(layer, onto: .hyper)
        return layer.bindings.filter { listed($0) && movesToHyper($0) }
            .map { row in
                let reason: ShortcutBaseLeftRow.Reason
                if let hold = kept.first(where: { $0.row == row }) {
                    reason = .taken(target: hold.target, by: hold.holder)
                } else if seeded[row.lua, default: []].contains(row.combo) {
                    reason = .predates
                } else {
                    reason = .ownChoice
                }
                return left(row, layer: layer.name, reason: reason)
            }
    }

    /// Shared rows the page does not draw and the switch left on
    /// `⌃⌥`, read off the base Save would write, so the draft's own
    /// layer edits and deletes are already in it.
    private func hiddenSharedRows(
        seeded: [String: Set<String>]
    ) -> [ShortcutBaseLeftRow] {
        guard let base = encodedReach?.keyBase else { return [] }
        let shown = Set(
            config.layers.flatMap { layer in
                layer.bindings.map {
                    RuleReachTable<String>.keyID(
                        layer: layer.name,
                        lua: $0.lua
                    )
                }
            }
        )
        return base.flatMap { layer in
            leftRows(of: layer, seeded: seeded) {
                !shown.contains(
                    RuleReachTable<String>.keyID(
                        layer: layer.name,
                        lua: $0.lua
                    )
                )
            }
        }
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
            id: [layer, row.lua, row.combo, reason.id]
                .joined(separator: "␟"),
            row: row,
            reason: reason
        )
    }

    /// The seed's own `⌃⌥` chords per action — the shipped set, and
    /// the digits a top-up gave the live-only Spaces: a row still on
    /// one predates the switch.
    private var seededChords: [String: Set<String>] {
        let spaces = liveOnlyShortcutSpaces.shortcutSpaces(
            after: config.spaces
        )
        let seed =
            shippedDefaults(on: .standard)
            + (1...DefaultKeybindings.digitCapacity).compactMap {
                DefaultKeybindings.desktopRow($0, base: .standard)
            }
            + DefaultKeybindings.digitTopUp(
                existing: [],
                spaces: spaces,
                base: .standard
            )
        return seed.reduce(into: [:]) {
            $0[$1.lua, default: []].insert($1.combo)
        }
    }

    /// Every profile's own layer rows but the page's, by name, as
    /// the Save would write them — a row the switch kept on its old
    /// chord for a profile included (`KeyLayerOverride.following`).
    private var otherProfileOverrides: [(String, KeyLayerOverride)] {
        guard let stored = layeredReach ?? ruleReachStored else {
            return []
        }
        return stored.storedKeyOverrides
            .filter { $0.key != reachPage }
            .sorted { $0.key < $1.key }
    }
}

/// One row the switch left on `⌃⌥`, with why; `ShortcutBaseWords`
/// names it.
struct ShortcutBaseLeftRow: Identifiable, Equatable {
    enum Reason: Equatable {
        /// On the seed's own chord: the row predates the switch.
        case predates
        /// The `✦` chord it would take is another row's.
        case taken(target: String, by: KeyBinding)
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
    let row: KeyBinding
    let reason: Reason
}
