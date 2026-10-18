import Foundation

/// Drops the machine-local leaves from `gui.json` and from a
/// bundle's inline `config` (#2324, `MachineConfigMigrationTests`):
/// `desktop_spaces` lives in `machine.json` from
/// `MachineConfig.movedAtFormat` and never travels.
/// `GuiConfigStore.load` carries a `gui.json`'s copy across before
/// this step rewrites the file; a bundle's copy is another Mac's
/// memory and is dropped.
extension ConfigMigration {
    /// Spelled here rather than derived: a historical step keeps
    /// the names it was written for.
    static let movedMachineKeys = ["desktop_spaces"]

    @Sendable
    static func migratingMachineLeavesOut(_ data: Data) -> Data? {
        surgicallyApplying(
            data,
            gate: { data in
                stampBelow(
                    data,
                    file: MachineConfig.movedAtFormat,
                    bundle: SetupBundle.machineLeavesDroppedAtFormat
                )
                    && movedMachineKeys.contains {
                        data.range(of: Data("\"\($0)\"".utf8)) != nil
                    }
            },
            rewriting: machineLeavesDropped,
            editing: droppingMachineLeaves
        )
    }

    /// The root with each moved key gone from a `gui.json` root
    /// or a bundle's `config`; nothing else is walked.
    static func machineLeavesDropped(_ node: Any) -> (Any, Bool) {
        guard var root = node as? [String: Any] else {
            return (node, false)
        }
        switch shape(of: root) {
        case .gui:
            let changed = movedMachineKeys.contains { root[$0] != nil }
            for key in movedMachineKeys { root[key] = nil }
            return (root, changed)
        case .bundle:
            guard var config = root["config"] as? [String: Any],
                movedMachineKeys.contains(where: { config[$0] != nil })
            else { return (root, false) }
            for key in movedMachineKeys { config[key] = nil }
            root["config"] = config
            return (root, true)
        case .profile, .palettes, .looks:
            return (root, false)
        }
    }

    /// The textual edit: each `"key" : { … }` entry removed with
    /// one neighbouring comma. The map is flat, so `[^{}]*` spans
    /// it; the envelope's re-parse refuses anything else.
    private static func droppingMachineLeaves(_ text: String) -> Data? {
        var out = text
        for key in movedMachineKeys {
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
