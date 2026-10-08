import Foundation

/// Layer-level edits over the stored shortcut files (#2022): a
/// layer's profiles, a delete and a rename are laid over the
/// stored base and overrides AHEAD of the key table, so a row edit
/// encodes against the layers the draft already has, and a save
/// writes every file whose layers moved.
extension RuleReachSnapshot {
    /// Rewrites `transforms`' profiles' resolved layers through
    /// their own transform, and the base through `base`, as if the
    /// files held the result. Each rewritten list is stored as its
    /// sparse diff against the new base. A profile no transform
    /// names keeps the layers it resolved, re-encoded only where
    /// the new base would change them or its override names a
    /// layer the base no longer holds — so a writer dropping a base
    /// layer clears every left-out mark naming it.
    ///
    /// The layer pass runs AHEAD of the row encode: the key table is
    /// rebuilt from the rewritten files, so it throws rather than
    /// discard a row edit already encoded into it.
    public mutating func rewriteLayers(
        _ transforms: [String: ([KeyLayer]) -> [KeyLayer]],
        base: (([KeyLayer]) -> [KeyLayer])? = nil
    ) throws {
        guard keyLayers.baseTouched.isEmpty,
            keyLayers.touched.values.allSatisfy(\.isEmpty)
        else { throw LayerPassError.afterRowEncode }
        let profiles = keyLayers.profiles
        var before: [String: [KeyLayer]] = [:]
        for profile in profiles {
            before[profile] = storedKeyLayers(for: profile)
        }
        if let base { storedKeyBase = base(storedKeyBase) }
        let baseNames = Set(storedKeyBase.map(\.name))
        for profile in profiles {
            let old = before[profile] ?? storedKeyBase
            let original = storedKeyOverrides[profile]
            if let transform = transforms[profile] {
                storedKeyOverrides[profile] = KeyLayerOverride.diff(
                    base: storedKeyBase,
                    edited: transform(old)
                )
                continue
            }
            let stale = original?.leftOut.contains {
                !baseNames.contains($0)
            }
            guard
                stale == true
                    || !RuleReachTable<String>.sameShortcuts(
                        storedKeyLayers(for: profile),
                        old
                    )
            else { continue }
            storedKeyOverrides[profile] = KeyLayerOverride.diff(
                base: storedKeyBase,
                edited: old
            )
        }
        keyLayers = .keyLayers(
            base: storedKeyBase,
            overrides: profiles.map { ($0, storedKeyOverrides[$0]) }
        )
        RuleReachTable<String>.collectTemplates(
            storedKeyBase,
            into: &keyTemplates
        )
        for profile in profiles {
            RuleReachTable<String>.collectTemplates(
                storedKeyLayers(for: profile),
                into: &keyTemplates
            )
        }
    }

    /// Which profiles hold each layer, as a reach table keyed by
    /// layer name: a base layer is the shared rule, a base layer a
    /// profile leaves out is left out, and a layer only some
    /// profiles carry is each one's own entry.
    public var layerTable: RuleReachTable<Bool> {
        var base: [String: Bool] = [:]
        for layer in storedKeyBase { base[layer.name] = true }
        var entries: [String: [String: Bool?]] = [:]
        for profile in keyLayers.profiles {
            let held = Set(storedKeyLayers(for: profile).map(\.name))
            var own: [String: Bool?] = [:]
            for name in held where base[name] == nil {
                own[name] = true
            }
            for name in base.keys where !held.contains(name) {
                own.updateValue(nil, forKey: name)
            }
            entries[profile] = own
        }
        return RuleReachTable(
            base: base,
            entries: entries,
            profiles: keyLayers.profiles
        )
    }
}

/// Why a layer pass was refused.
public enum LayerPassError: Error, Equatable {
    /// The key table already holds row edits the pass would drop.
    case afterRowEncode
}
