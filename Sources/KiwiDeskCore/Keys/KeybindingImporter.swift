import Foundation

/// Reconstructs `[KeyLayer]` from live keybindings (`LuaBindingBody`, #4).
@MainActor
enum KeybindingImporter {
    /// Builds layers from manager reading binding source bodies
    /// (`KiwiCore.recoverKeybindings`).
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
