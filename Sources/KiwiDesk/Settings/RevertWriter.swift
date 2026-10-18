import KiwiDeskCore

/// One census key's way back to the draft's baseline (#792): the
/// leaves `SettingsDraftDiff` books to the key, copied from
/// `cleanConfig` into `config`, at a row's instance where the key
/// is kept per instance and whole where the row names none.
@MainActor
struct RevertWriter {
    /// The model paths the writer copies, spelled as census ids
    /// spell them, so `SettingsRevertRegisterTests` can hold each
    /// writer to its key.
    let paths: [String]
    let apply: (SettingsModel, _ instance: String?) -> Void

    /// One leaf, whole.
    static func leaf<V>(_ path: WritableKeyPath<GuiConfig, V>) -> Self {
        Self(paths: [spelled(path)]) { model, _ in
            model.config[keyPath: path] = model.cleanConfig[keyPath: path]
        }
    }

    /// One entry of a per-instance map, or the whole map for a row
    /// that names no entry.
    static func entry<K: Hashable, V>(
        _ path: WritableKeyPath<GuiConfig, [K: V]>,
        key: @escaping (String) -> K
    ) -> Self {
        Self(paths: [spelled(path) + "[]"]) { model, instance in
            let clean = model.cleanConfig[keyPath: path]
            guard let instance else {
                model.config[keyPath: path] = clean
                return
            }
            let entry = key(instance)
            model.config[keyPath: path][entry] = clean[entry]
        }
    }

    /// One optional field of a per-instance override: the field
    /// takes the baseline's, and an entry the baseline lacks is
    /// dropped once nothing is left in it. A draft that dropped
    /// the whole entry gets the baseline's entry back.
    static func entryField<K: Hashable, O, F>(
        _ path: WritableKeyPath<GuiConfig, [K: O]>,
        _ field: WritableKeyPath<O, F?>,
        key: @escaping (String) -> K
    ) -> Self {
        let name = spelled(path) + "[]." + spelled(field)
        return Self(paths: [name]) { model, instance in
            let clean = model.cleanConfig[keyPath: path]
            var draft = model.config[keyPath: path]
            let keys =
                instance.map { [key($0)] }
                ?? Array(Set(draft.keys).union(clean.keys))
            for entry in keys {
                guard var value = draft[entry] else {
                    draft[entry] = clean[entry]
                    continue
                }
                value[keyPath: field] = clean[entry]?[keyPath: field]
                draft[entry] =
                    clean[entry] == nil && allNil(value) ? nil : value
            }
            model.config[keyPath: path] = draft
        }
    }

    /// One entry of a rule list, named by its row's
    /// `ListEntryInstance`: an added copy leaves (the draft's last),
    /// a removed one returns at its baseline place; a row naming no
    /// entry — a reorder — takes the whole list back.
    static func list(_ path: WritableKeyPath<GuiConfig, [String]>) -> Self {
        Self(paths: [spelled(path)]) { model, instance in
            let clean = model.cleanConfig[keyPath: path]
            guard let instance,
                let parsed = ListEntryInstance(parsing: instance)
            else {
                model.config[keyPath: path] = clean
                return
            }
            var draft = model.config[keyPath: path]
            if parsed.added {
                if let last = draft.lastIndex(of: parsed.entry) {
                    draft.remove(at: last)
                }
            } else {
                let at = clean.firstIndex(of: parsed.entry) ?? draft.count
                draft.insert(parsed.entry, at: min(at, draft.count))
            }
            model.config[keyPath: path] = draft
        }
    }

    /// One member of a set, named by its row: in or out as the
    /// baseline has it, and the whole set for a row naming none.
    static func setMember<E: Hashable>(
        _ path: WritableKeyPath<GuiConfig, Set<E>>,
        key: @escaping (String) -> E
    ) -> Self {
        Self(paths: [spelled(path)]) { model, instance in
            let clean = model.cleanConfig[keyPath: path]
            guard let instance else {
                model.config[keyPath: path] = clean
                return
            }
            let member = key(instance)
            if clean.contains(member) {
                model.config[keyPath: path].insert(member)
            } else {
                model.config[keyPath: path].remove(member)
            }
        }
    }

    /// Several writers as one: a master's followers (#1383).
    static func all(_ writers: [RevertWriter]) -> Self {
        Self(paths: writers.flatMap(\.paths)) { model, instance in
            for writer in writers { writer.apply(model, instance) }
        }
    }

    /// This writer, then `after` — a rule family's reach (#1393).
    func then(
        _ after: @escaping (SettingsModel, String?) -> Void
    ) -> Self {
        let apply = self.apply
        return Self(paths: paths) { model, instance in
            apply(model, instance)
            after(model, instance)
        }
    }

    /// `\GuiConfig.settings.bsp.override` as `settings.bsp.override`,
    /// and a top-level field as `config.<name>`, as census ids
    /// spell them.
    private static func spelled(_ path: AnyKeyPath) -> String {
        let text = String(describing: path)
        let body = text.drop { $0 != "." }.dropFirst()
        guard text.hasPrefix("\\GuiConfig.") else { return String(body) }
        return body.hasPrefix("settings") ? String(body) : "config." + body
    }

    /// Whether every stored field of an override is unset.
    private static func allNil(_ value: Any) -> Bool {
        Mirror(reflecting: value).children.allSatisfy {
            let field = Mirror(reflecting: $0.value)
            return field.displayStyle == .optional && field.children.isEmpty
        }
    }
}
