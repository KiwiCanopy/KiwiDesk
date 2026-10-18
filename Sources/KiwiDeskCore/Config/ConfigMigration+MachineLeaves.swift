import Foundation

/// Moves the machine-local leaves out of `gui.json` and out of a
/// bundle's inline `config` (#2324, `MachineConfigTests`): each
/// `MachineConfig.moves` entry's keys, below that entry's format.
/// `GuiConfigStore.load` carries a `gui.json`'s copy into its
/// machine-folder file before this step rewrites the file. In a
/// bundle a leaf that travels is lifted to the bundle's top level,
/// and one that does not is another Mac's and is dropped.
extension ConfigMigration {
    /// Set while the store prepares the values its carry reads:
    /// every other step runs, this one stands down, so an old
    /// shape is rewritten before the leaf leaves.
    @TaskLocal static var keepsMachineLeaves = false

    /// `data` migrated with the leaves still in place, nil where
    /// nothing migrates — the carry's input.
    static func migratedKeepingMachineLeaves(_ data: Data) -> Data? {
        $keepsMachineLeaves.withValue(true) { migrated(data) }
    }

    @Sendable
    static func migratingMachineLeavesOut(_ data: Data) -> Data? {
        guard !keepsMachineLeaves else { return nil }
        return surgicallyApplying(
            data,
            gate: { data in
                MachineConfig.moves.contains { move in
                    stampBelow(
                        data,
                        file: move.guiFormat,
                        bundle: move.bundleFormat
                    )
                        && move.keys.contains {
                            data.range(of: Data("\"\($0)\"".utf8)) != nil
                        }
                }
            },
            rewriting: machineLeavesDropped,
            editing: droppingMachineLeaves
        )
    }

    /// The moves a root at `format` still owes, for its shape's
    /// floor.
    private static func owedMoves(
        format: Int,
        bundle: Bool
    ) -> [MachineConfig.Move] {
        MachineConfig.moves.filter {
            format < (bundle ? $0.bundleFormat : $0.guiFormat)
        }
    }

    /// The root with each owed key gone from a `gui.json` root, or
    /// from a bundle's `config` — lifted to the bundle's top level
    /// where the move travels; nothing else is walked.
    static func machineLeavesDropped(_ node: Any) -> (Any, Bool) {
        guard var root = node as? [String: Any] else {
            return (node, false)
        }
        let format = root["format"] as? Int ?? 0
        switch shape(of: root) {
        case .gui:
            let keys = owedMoves(format: format, bundle: false)
                .flatMap(\.keys)
            let changed = keys.contains { root[$0] != nil }
            for key in keys { root[key] = nil }
            return (root, changed)
        case .bundle:
            guard var config = root["config"] as? [String: Any]
            else { return (root, false) }
            var changed = false
            for move in owedMoves(format: format, bundle: true) {
                for key in move.keys where config[key] != nil {
                    if let field = move.bundleField, root[field] == nil {
                        root[field] = config[key]
                    }
                    config[key] = nil
                    changed = true
                }
            }
            root["config"] = config
            return (root, changed)
        case .profile, .palettes, .looks:
            return (root, false)
        }
    }

    /// The textual edit: each flat `"key" : { … }` entry removed
    /// with one neighbouring comma. A nested value (the bindings)
    /// or a lift never matches it, so those take the envelope's
    /// re-serialized fallback — accepted, since a `gui.json`
    /// crosses once.
    private static func droppingMachineLeaves(_ text: String) -> Data? {
        var out = text
        for key in MachineConfig.moves.flatMap(\.keys) {
            let entry = "\"\(key)\"\\s*:\\s*\\{[^{}]*\\}"
            for pattern in ["\\s*\(entry)\\s*,", ",\\s*\(entry)"] {
                guard let regex = try? NSRegularExpression(pattern: pattern)
                else { return nil }
                let whole = NSRange(out.startIndex..., in: out)
                out = regex.stringByReplacingMatches(
                    in: out,
                    range: whole,
                    withTemplate: ""
                )
            }
        }
        return Data(out.utf8)
    }
}
