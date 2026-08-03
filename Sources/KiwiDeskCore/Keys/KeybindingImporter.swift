import Foundation

/// Reconstructs the GUI's `[KeyLayer]` from the live keybindings
/// (#4). Each bound `(KeyCombo, ref)` becomes a row: the combo is
/// formatted back to its canonical string, and the action text is
/// recovered from the source file via `debug.getinfo`'s line
/// range (`LuaBindingBody`).
///
/// Every recovered row is emitted as `.custom` holding the raw
/// body; the GUI upgrades exact catalog matches to
/// `.navigation`/`.application` afterwards, since only the GUI
/// knows that catalog. A row whose action cannot be recovered is
/// dropped rather than emitted with an empty body — an empty body
/// would overwrite a working binding with a no-op on the next
/// save. Combos alone are never enough (issue #4).
///
/// `@MainActor`: reads the main-actor `LuaInterpreter` and
/// `KeybindingManager`, matching its only caller,
/// `KiwiCore.recoverKeybindings`.
@MainActor
enum KeybindingImporter {
    /// Builds layers from `manager`, reading each binding's source
    /// through `interpreter` and `readFile` (path → contents).
    static func layers(
        from manager: KeybindingManager,
        interpreter: LuaInterpreter,
        readFile: (String) -> String?
    ) -> [KeyLayer] {
        var cache: [String: String] = [:]
        return manager.definedLayers.map { name in
            var rows: [KeyBinding] = []
            for (combo, ref) in manager.bindings(for: name) {
                guard let text = combo.comboString(),
                    let lua = action(
                        ref: ref,
                        interpreter: interpreter,
                        readFile: readFile,
                        cache: &cache
                    )
                else { continue }
                rows.append(
                    KeyBinding(combo: text, lua: lua, kind: .custom)
                )
            }
            rows.sort { $0.combo < $1.combo }
            return KeyLayer(
                name: name,
                icon: manager.icon(for: name),
                bindings: rows
            )
        }
    }

    /// The recovered, non-empty action body for one binding, or
    /// nil when its source is a C function, a named (non-inline)
    /// Lua handler, an unreadable file, or an unbalanced range —
    /// see `LuaBindingBody` for the inline-literal assumption.
    private static func action(
        ref: Int32,
        interpreter: LuaInterpreter,
        readFile: (String) -> String?,
        cache: inout [String: String]
    ) -> String? {
        guard let info = interpreter.functionSource(ref: ref),
            info.source.hasPrefix("@")
        else { return nil }
        let path = String(info.source.dropFirst())
        let contents: String
        if let cached = cache[path] {
            contents = cached
        } else if let loaded = readFile(path) {
            cache[path] = loaded
            contents = loaded
        } else {
            return nil
        }
        let body = LuaBindingBody.extract(
            from: contents,
            firstLine: info.firstLine,
            lastLine: info.lastLine
        )
        guard let body, !body.isEmpty else { return nil }
        return body
    }
}
