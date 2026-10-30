import Foundation

extension KeybindingConflicts {
    /// Every row's conflict in one layer, keyed by the row's id,
    /// with each combo parsed once: what `conflict(for:in:)`
    /// answers row by row, for a page that asks for every row at
    /// once (#2783, `LayerConflictsTests`).
    public static func rowConflicts(
        of bindings: [KeyBinding],
        distinguishingSides: Bool
    ) -> [UUID: Conflict] {
        let parsed = bindings.map {
            $0.combo.isEmpty ? nil : KeyCombo.parse($0.combo)
        }
        var byChord: [KeyCombo: [Int]] = [:]
        for (index, combo) in parsed.enumerated() {
            if let combo {
                byChord[combo.registered, default: []].append(index)
            }
        }
        var result: [UUID: Conflict] = [:]
        for (index, binding) in bindings.enumerated()
        where !binding.combo.isEmpty {
            guard let combo = parsed[index] else {
                result[binding.id] = Conflict(
                    binding: binding,
                    target: .unrecognized
                )
                continue
            }
            let rivals = (byChord[combo.registered] ?? []).lazy.compactMap {
                index in parsed[index].map { (bindings[index], $0) }
            }
            result[binding.id] = conflict(
                for: binding,
                parsed: combo,
                among: rivals,
                distinguishingSides: distinguishingSides
            )
        }
        return result
    }
}
