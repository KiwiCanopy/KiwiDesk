import Foundation

/// Crosses `space.cue` (#2228) to `space.transition` (#2524,
/// `SpaceTransitionMigrationTests`): the toggle became a three-way
/// choice. `true` becomes `slide` and `false` becomes `none` —
/// `space.cue` was written whole, so a stored `true` is mostly the
/// default, and the default is now the slide (owner ruling
/// #2524). Without the step the failure is SILENT: `Space` decodes
/// the group key by key, dropping an off.
///
/// Scoped to a `space` object holding a boolean `cue`: `gui.json`'s
/// root and a bundle's inline `config`. A profile's `space` group
/// carries no `cue`, and `desktop.cue` and `mode.cue` stay.
extension ConfigMigration {
    /// Spelled rather than derived, as #1020's: a historical step
    /// keeps emitting the names it was written to emit.
    static let retiredSpaceCueKey = "cue"
    static let spaceTransitionKey = "transition"

    @Sendable
    static func migratingSpaceCueOntoTransition(_ data: Data) -> Data? {
        let needle = Data("\"\(retiredSpaceCueKey)\"".utf8)
        return surgicallyApplying(
            data,
            gate: { $0.range(of: needle) != nil },
            rewriting: { root in
                rewritingValues(of: root, at: "space") { value in
                    guard var group = value as? [String: Any],
                        let on = group[retiredSpaceCueKey] as? Bool
                    else { return nil }
                    group[retiredSpaceCueKey] = nil
                    if group[spaceTransitionKey] == nil {
                        group[spaceTransitionKey] = transition(on)
                    }
                    return group
                }
            },
            editing: surgicallyCrossedSpaceCue
        )
    }

    /// The stored transition a `space.cue` value crosses to.
    static func transition(_ on: Bool) -> String {
        on ? SpaceTransition.slide.rawValue : SpaceTransition.none.rawValue
    }

    /// The textual crossing, standing down unless exactly one
    /// `space` object holds the `cue` — the tree walk is the
    /// fallback, and the envelope re-parses whatever this returns.
    static func surgicallyCrossedSpaceCue(_ text: String) -> Data? {
        let pattern =
            "(\"space\"\\s*:\\s*\\{[^{}]*?)\"\(retiredSpaceCueKey)\""
            + "(\\s*:\\s*)(true|false)"
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            case let range = NSRange(text.startIndex..., in: text),
            regex.numberOfMatches(in: text, range: range) == 1,
            let match = regex.firstMatch(in: text, range: range),
            let whole = Range(match.range, in: text),
            let head = Range(match.range(at: 1), in: text),
            let colon = Range(match.range(at: 2), in: text),
            let value = Range(match.range(at: 3), in: text)
        else { return nil }
        let crossed =
            text[head] + "\"\(spaceTransitionKey)\"" + text[colon]
            + "\"\(transition(text[value] == "true"))\""
        return text.replacingCharacters(in: whole, with: crossed)
            .data(using: .utf8)
    }
}
