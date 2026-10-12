import Foundation

/// Space-level edits and reads of the draft.
extension GuiConfig {
    /// This draft's mode for every space in `spaces`, dense.
    ///
    /// The sparse encoding omits `.bsp`, and a reader that
    /// spells that default itself is a second copy of it — which
    /// is how a mode-scoped write can disagree with the apply
    /// beside it (#1179).
    public func modes(
        for spaces: [SpaceID]
    ) -> [SpaceID: LayoutMode] {
        var dense: [SpaceID: LayoutMode] = [:]
        for space in spaces {
            dense[space] = spaceModes[space] ?? .bsp
        }
        return dense
    }

    /// Renames a space across all references, overrides, and keybindings
    /// (#13).
    @discardableResult
    public mutating func renameSpace(
        from: SpaceID,
        to: SpaceID
    ) -> Bool {
        guard from != to else { return true }
        guard !to.raw.isEmpty else { return false }
        guard spaces.contains(from), !spaces.contains(to) else {
            return false
        }
        spaces = spaces.map { $0 == from ? to : $0 }
        if let mode = spaceModes.removeValue(forKey: from) {
            spaceModes[to] = mode
        }
        if let pin = spacePins.removeValue(forKey: from) {
            spacePins[to] = pin
        }
        if mainSpaces.remove(from) != nil {
            mainSpaces.insert(to)
        }
        if fallbackSpace == from { fallbackSpace = to }
        settings.renameSpace(from: from, to: to)
        for (app, space) in appRules where space == from {
            appRules[app] = to
        }
        layers = layers.map { layer in
            var layer = layer
            layer.bindings = layer.bindings.map { binding in
                var binding = binding
                binding.lua = SpaceLuaArg.rename(
                    in: binding.lua,
                    from: from.raw,
                    to: to.raw
                )
                return binding
            }
            return layer
        }
        // Rows a deleted `to` left behind (#92) now meet the
        // renamed ones; nothing else is touched.
        NavigationChords.deduplicate(&self, touching: to)
        return true
    }

    /// Deletes a space and all profile-scoped overrides (#68) — a
    /// pin left behind keeps the space in `Profile.declaredSpaces`
    /// and the next authoritative load resurrects it. Deliberately
    /// does NOT touch `appRules` (unlike `renameSpace`): app rules
    /// are global, and another profile may still declare a space
    /// of this name.
    public mutating func removeSpace(_ space: SpaceID) {
        spaces.removeAll { $0 == space }
        spaceModes[space] = nil
        spacePins[space] = nil
        mainSpaces.remove(space)
        if fallbackSpace == space { fallbackSpace = nil }
        settings.removeSpace(space)
    }

    /// True if deleting space would drop custom overrides (#205).
    /// The settings half probes by mutating a copy and comparing,
    /// so it can never drift from `TilingSettings.removeSpace`'s
    /// reflection-guarded map list.
    public func carriesOverrides(_ space: SpaceID) -> Bool {
        if spacePins[space] != nil { return true }
        if mainSpaces.contains(space) { return true }
        if fallbackSpace == space { return true }
        var probe = settings
        probe.removeSpace(space)
        return probe != settings
    }
}
