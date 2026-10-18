import Foundation

/// Drops the machine-local leaves from `gui.json` and from a
/// bundle's inline `config` (#2324, `MachineConfigTests`): each
/// `MachineConfig.moves` entry's keys, below that entry's format.
/// `GuiConfigStore.load` carries a `gui.json`'s copy into
/// `machine.json` before this step rewrites the file; a bundle's
/// copy is another Mac's and is dropped.
extension ConfigMigration {
    @Sendable
    static func migratingMachineLeavesOut(_ data: Data) -> Data? {
        surgicallyApplying(
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

    /// The keys a root at `format` still owes the move, for its
    /// shape's floor.
    private static func owedKeys(format: Int, bundle: Bool) -> [String] {
        MachineConfig.moves.filter {
            format < (bundle ? $0.bundleFormat : $0.guiFormat)
        }.flatMap(\.keys)
    }

    /// The root with each owed key gone from a `gui.json` root or
    /// a bundle's `config`; nothing else is walked.
    static func machineLeavesDropped(_ node: Any) -> (Any, Bool) {
        guard var root = node as? [String: Any] else {
            return (node, false)
        }
        let format = root["format"] as? Int ?? 0
        switch shape(of: root) {
        case .gui:
            let keys = owedKeys(format: format, bundle: false)
            let changed = keys.contains { root[$0] != nil }
            for key in keys { root[key] = nil }
            return (root, changed)
        case .bundle:
            let keys = owedKeys(format: format, bundle: true)
            guard var config = root["config"] as? [String: Any],
                keys.contains(where: { config[$0] != nil })
            else { return (root, false) }
            for key in keys { config[key] = nil }
            root["config"] = config
            return (root, true)
        case .profile, .palettes, .looks:
            return (root, false)
        }
    }

    /// The textual edit: each `"key" : { … }` entry removed with
    /// one neighbouring comma. The maps are flat, so `[^{}]*` spans
    /// one; the envelope's re-parse refuses anything else.
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
