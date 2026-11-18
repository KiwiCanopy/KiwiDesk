import KiwiDeskCore

/// The gesture rows still on `⌃⌥` while the base is `✦` (#3444), the
/// keyboard list's twin (`rowsLeftOnStandard`): the page's rows the
/// switch would move, each with its reason, then the other profiles'
/// own rows, which the switch never moves.
extension SettingsModel {
    var gestureRowsLeftOnStandard: [GestureBaseLeftRow] {
        guard config.shortcutBase == .hyper else { return [] }
        let resolved = GestureSeeds.resolved(
            base: config.gesture,
            profile: nil,
            shortcutBase: .hyper
        )
        let kept = GestureBaseSwitch.kept(in: resolved, onto: .hyper)
        var rows: [GestureBaseLeftRow] = []
        for (key, action) in resolved.sorted(by: { $0.key < $1.key }) {
            guard ShortcutBase.moved(key, to: .hyper) != nil else {
                continue
            }
            // No seed lies on ⌃⌥ under ✦, so a row there is the
            // user's, or one another row's ✦ key held back.
            let reason: GestureBaseLeftRow.Reason =
                kept.first { $0.key == key }
                .flatMap { hold in
                    resolved[hold.holder].map {
                        .taken(target: hold.target, by: $0)
                    }
                } ?? .ownChoice
            rows.append(GestureBaseLeftRow(key, action, reason))
        }
        guard let stored = layeredReach ?? ruleReachStored else {
            return rows
        }
        for profile in stored.gestures.profiles.sorted()
        where profile != reachPage {
            let own = stored.gestures.gestureOverride(for: profile)
            for (key, entry) in (own?.entries ?? [:])
                .sorted(by: { $0.key < $1.key })
            {
                guard let action = entry.action,
                    ShortcutBase.moved(key, to: .hyper) != nil
                else { continue }
                rows.append(
                    GestureBaseLeftRow(key, action, .profile(profile))
                )
            }
        }
        return rows
    }
}

/// One gesture row the switch left on `⌃⌥`, with why;
/// `ShortcutBaseWords.line` names it.
struct GestureBaseLeftRow: Identifiable, Equatable {
    enum Reason: Equatable {
        /// The `✦` key it would take holds another row.
        case taken(target: GestureKey, by: GestureAction)
        case ownChoice
        case profile(String)
    }

    let key: GestureKey
    let action: GestureAction
    let reason: Reason

    init(_ key: GestureKey, _ action: GestureAction, _ reason: Reason) {
        self.key = key
        self.action = action
        self.reason = reason
    }

    var id: String {
        let profile: String
        if case .profile(let name) = reason {
            profile = name
        } else {
            profile = ""
        }
        return ["gesture", key.spelling, profile].joined(separator: "␟")
    }
}
