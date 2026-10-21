import Foundation

/// Reconstructs `[KeyLayer]` from live keybindings
/// (`LuaBindingBody`, #4). A row whose action cannot be recovered
/// is DROPPED, never emitted with an empty body — an empty body
/// would overwrite a working binding with a no-op on the next
/// save.
@MainActor
enum KeybindingImporter {
    /// Reads a binding's source file as the importer expects.
    static func readSource(_ path: String) -> String? {
        try? String(contentsOfFile: path, encoding: .utf8)
    }

    /// Builds layers from manager reading binding source bodies
    /// (`KiwiCore.recoverKeybindings`). Drop-only: a row whose
    /// body cannot be read back is absent.
    static func layers(
        from manager: KeybindingManager,
        interpreter: LuaInterpreter,
        readFile: (String) -> String?
    ) -> [KeyLayer] {
        capture(
            from: manager,
            interpreter: interpreter,
            readFile: readFile
        ).layers
    }

    /// The recovered layers, and per layer the chords whose body
    /// could not be read back (#2482). The unread chords are
    /// plain strings and never a `KeyBinding`, so no save path
    /// can turn one into a no-op row.
    static func capture(
        from manager: KeybindingManager,
        interpreter: LuaInterpreter,
        readFile: (String) -> String?
    ) -> (layers: [KeyLayer], unread: [String: [String]]) {
        var cache: [String: String] = [:]
        var unread: [String: [String]] = [:]
        let layers = manager.definedLayers.map { name in
            var rows: [KeyBinding] = []
            for (combo, ref) in manager.bindings(for: name) {
                guard let text = combo.comboString() else { continue }
                guard
                    let lua = action(
                        ref: ref,
                        interpreter: interpreter,
                        readFile: readFile,
                        cache: &cache
                    )
                else {
                    unread[name, default: []].append(text)
                    continue
                }
                rows.append(
                    KeyBinding(combo: text, lua: lua, kind: .custom)
                )
            }
            rows.sort { $0.combo < $1.combo }
            unread[name]?.sort()
            return KeyLayer(
                name: name,
                icon: manager.icon(for: name),
                bindings: rows
            )
        }
        return (layers, unread)
    }

    /// The recovered, non-empty action body for one binding, its
    /// scalar upvalues spelled as literals and a Space call as the
    /// catalog spells it (#2485), or nil when its source is a C
    /// function, a named (non-inline) Lua handler, an unreadable
    /// file, or an unbalanced range — see `LuaBindingBody` for the
    /// inline-literal assumption.
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
        return SpaceLuaArg.catalogSpelling(
            of: LuaUpvalueLiterals.resolve(
                body: body,
                upvalues: interpreter.functionUpvalues(ref: ref),
                file: contents
            )
        )
    }
}
