import Foundation

extension KiwiCore {
    /// Builds `layer`'s key sequences for the tap (#1871), minting
    /// each end key's ref. A leader that does not parse, or an end
    /// key that does not compile, is skipped and filed under the
    /// leader's chord, the row Settings draws; a later sequence on
    /// one leader wins, as a later row does.
    func prepareSequences(
        _ layer: KeyLayer,
        lua: LuaInterpreter
    ) -> (
        sequences: [KeySequence],
        bindings: [KeyBinding],
        skipped: [InstalledKeybindings.Skipped]
    ) {
        var built: [(sequence: KeySequence, binding: KeyBinding)] = []
        var skipped: [InstalledKeybindings.Skipped] = []
        for row in layer.sequences where !row.combo.isEmpty {
            var reason: DeadShortcutReason?
            let result = KeySequence.build(row) { end in
                switch lua.makeFunction(body: end.lua) {
                case .success(let ref): return ref
                case .failure(let error):
                    onLog("structured: sequence key skipped: \(error)")
                    if case .runtime(let message) = error {
                        reason = .luaError(message)
                    }
                    return nil
                }
            }
            guard let sequence = result.sequence else {
                onLog("structured: invalid leader '\(row.combo)'")
                skipped.append(
                    .init(
                        layer: layer.name,
                        chord: row.combo,
                        reason: .invalidChord
                    )
                )
                continue
            }
            if !result.skipped.isEmpty {
                skipped.append(
                    .init(
                        layer: layer.name,
                        chord: row.combo,
                        reason: reason ?? .invalidChord
                    )
                )
            }
            if let old = built.firstIndex(where: {
                $0.sequence.leader == sequence.leader
            }) {
                built[old].sequence.refs.forEach { lua.release(ref: $0) }
                built.remove(at: old)
            }
            built.append((sequence, row))
        }
        return (built.map(\.sequence), built.map(\.binding), skipped)
    }
}
