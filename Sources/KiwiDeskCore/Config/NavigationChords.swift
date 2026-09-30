import Foundation

/// One chord per navigation action per layer (#1797, #1807): the
/// one dedupe every GUI writer of layer rows takes. A Shortcuts row
/// draws one chord per action, so a second is invisible yet still
/// registered. `NavigationChordWriterTests` drives every writer.
public enum NavigationChords {
    /// A chord a dedupe removed, and the one its action kept.
    public struct Dropped: Equatable, Sendable {
        public let dropped: KeyBinding
        public let kept: KeyBinding
    }

    /// What "the same action" compares: a Space verb by its verb
    /// and Space (`"1"` and `1` alike), anything else by its Lua.
    enum Action: Hashable {
        case space(SpaceLuaArg.Target)
        case lua(String)

        var space: SpaceID? {
            if case .space(let target) = self { return target.space }
            return nil
        }
    }

    /// `rows` with each `navigation` action's extra chords removed,
    /// keeping a Space verb's own digit, else the first. A Space verb
    /// naming a Space outside `liveSpaces` is an orphan (#92), drawn
    /// one row per binding, so it is never removed.
    public static func deduplicated(
        _ rows: [KeyBinding],
        liveSpaces: Set<SpaceID>,
        touching space: SpaceID? = nil
    ) -> (rows: [KeyBinding], dropped: [Dropped]) {
        var groups: [Action: [Int]] = [:]
        var order: [Action] = []
        for (index, row) in rows.enumerated() {
            guard let action = action(of: row, liveSpaces: liveSpaces),
                space == nil || action.space == space
            else { continue }
            if groups[action] == nil { order.append(action) }
            groups[action, default: []].append(index)
        }
        var drop: [Int: Int] = [:]
        for action in order {
            guard let indices = groups[action], indices.count > 1
            else { continue }
            let keep =
                indices.first { isOwnDigit(rows[$0], action) }
                ?? indices[0]
            for index in indices where index != keep {
                drop[index] = keep
            }
        }
        guard !drop.isEmpty else { return (rows, []) }
        let kept = rows.enumerated()
            .filter { drop[$0.offset] == nil }.map(\.element)
        let dropped = drop.keys.sorted().compactMap { index in
            drop[index].map {
                Dropped(dropped: rows[index], kept: rows[$0])
            }
        }
        return (kept, dropped)
    }

    /// Every layer of `config` deduplicated against its own Spaces —
    /// only the verbs naming `space` when one is given; returns what
    /// was dropped.
    @discardableResult
    public static func deduplicate(
        _ config: inout GuiConfig,
        touching space: SpaceID? = nil
    ) -> [Dropped] {
        let live = Set(config.spaces)
        var dropped: [Dropped] = []
        for index in config.layers.indices {
            let result = deduplicated(
                config.layers[index].bindings,
                liveSpaces: live,
                touching: space
            )
            config.layers[index].bindings = result.rows
            dropped += result.dropped
        }
        return dropped
    }

    private static func action(
        of row: KeyBinding,
        liveSpaces: Set<SpaceID>
    ) -> Action? {
        guard row.kind == .navigation else { return nil }
        guard let target = SpaceLuaArg.target(of: row.lua) else {
            return .lua(row.lua)
        }
        return liveSpaces.contains(target.space) ? .space(target) : nil
    }

    /// Whether the row's key is the Space's own digit, its keypad
    /// twin included (#1074).
    private static func isOwnDigit(
        _ row: KeyBinding,
        _ action: Action
    ) -> Bool {
        guard case .space(let target) = action,
            let digit = DefaultKeybindings.ownDigit(of: target.space),
            let own = KeyCombo.parse(digit)?.keyCode,
            let code = KeyCombo.parse(row.combo)?.keyCode
        else { return false }
        return code == own || KeypadKeys.rowTwin(of: code) == own
    }
}
