import Foundation

/// The Desktop half of the bridge: which Desktop a display
/// shows and switching it (#26), the Desktop lifecycle, names,
/// and the per-Desktop key/value store. Every id is a
/// WindowServer space id — a Desktop or a fullscreen space,
/// never a KiwiDesk space, which the WindowServer knows nothing
/// about (#884's semantics note).
extension WMBridge {
    // MARK: - Reads

    /// The full display/spaces model as the WindowServer holds
    /// it — the same plist `SLSCopyManagedDisplaySpaces` returns.
    /// Internal on purpose: it is the availability probe (a
    /// synchronous read that must ANSWER), and the census stays
    /// `NativeSpaces.allSpaces()`'s — one reader of
    /// `"Display Identifier"`, `"Current Space"` and the space
    /// list, which a caller verifying a bridge write reads too.
    static func managedDisplaySpaces() -> [[String: Any]]? {
        let op = make(
            "CopyManagedDisplaySpacesOperation",
            initializer: "init"
        ) { instance, selector in
            sender(as: InitFn.self)?(instance, selector)
        }
        return field("propertyListArray", of: performSync(op))
    }

    /// The Desktop's name (empty for an unnamed one), or nil
    /// without the bridge.
    public static func name(of space: SpaceID) -> String? {
        let op = make(
            "SpaceCopyNameOperation",
            initializer: "initWithSpaceID:"
        ) { instance, selector in
            sender(as: InitIDFn.self)?(instance, selector, space)
        }
        return field("string", of: performSync(op))
    }

    /// KiwiDesk's own entries in the Desktop's store, keys as the
    /// caller wrote them — the read half of `setValues(_:of:)`,
    /// which prefixes on the way in, so this strips on the way
    /// out. Apple's entries are `values(of:)`'s.
    public static func stamps(of space: SpaceID) -> [String: Any]? {
        guard let values = values(of: space) else { return nil }
        var out: [String: Any] = [:]
        for (key, value) in values where key.hasPrefix(valueKeyPrefix) {
            out[String(key.dropFirst(valueKeyPrefix.count))] = value
        }
        return out
    }

    /// The Desktop's whole store as the WindowServer holds it —
    /// Apple's own dictionary (`type`, `id64`, `uuid`,
    /// `WindowManagerInfo`, …) with KiwiDesk's `valueKeyPrefix`
    /// keys beside them, prefixed. A caller reading its own
    /// entries takes `stamps(of:)`.
    public static func values(of space: SpaceID) -> [String: Any]? {
        let op = make(
            "SpaceCopyValuesOperation",
            initializer: "initWithSpaceID:"
        ) { instance, selector in
            sender(as: InitIDFn.self)?(instance, selector, space)
        }
        return field("propertyListDictionary", of: performSync(op))
    }

    // MARK: - Writes (dispatched, never confirmed — see WMBridge)

    /// Points `displayIdentifier` at `space` (#26) — and that is
    /// ALL it does (#1023): the WindowServer moves the
    /// current-space pointer and composites the new space's
    /// windows, but never hides the old space's, so on its own
    /// this leaves both Desktops rendering at once while every
    /// pointer read — `SLSGetActiveSpace`,
    /// `SLSManagedDisplayGetCurrentSpace`, the managed-display
    /// plist — reports the switch as landed (device-measured
    /// 2026-08-26, macOS 26.6.2, both displays). A switching
    /// caller therefore pairs an accepted dispatch with
    /// `hideSpaces` of the space that display showed, which is
    /// the half of the transition the Dock performs and this
    /// write does not.
    public static func setCurrentSpace(
        _ space: SpaceID,
        displayIdentifier: String
    ) -> Bool {
        let op = make(
            "ManagedDisplaySetCurrentSpaceOperation",
            initializer: "initWithDisplayIdentifier:spaceID:"
        ) { instance, selector in
            sender(as: InitObjectIDFn.self)?(
                instance,
                selector,
                displayIdentifier as NSString,
                space
            )
        }
        return performAsync(op)
    }

    /// Removes `spaces`' windows from the compositor — the half
    /// of a Desktop switch `setCurrentSpace` leaves unperformed
    /// (#1023). The bare C symbol is a silent no-op from a
    /// foreign process; this operation is not, and set-then-hide
    /// measured as a complete switch — pointer moved AND the
    /// destination's windows composited within ~130 ms — on
    /// device 2026-08-26 (macOS 26.6.2). No `showSpaces` twin is
    /// wrapped on purpose: the set itself composites the target,
    /// measured against both a Dock-hidden and a bridge-hidden
    /// space, so a show would be a write nothing needs.
    public static func hideSpaces(_ spaces: [SpaceID]) -> Bool {
        let op = make(
            "HideSpacesOperation",
            initializer: "initWithSpaces:"
        ) { instance, selector in
            sender(as: InitObjectFn.self)?(
                instance,
                selector,
                spaces.map { NSNumber(value: $0) } as NSArray
            )
        }
        return performAsync(op)
    }

    /// Creates a real managed Desktop — it joins Mission
    /// Control's user list (#889 item 1) — and returns its id.
    /// `values` seeds its key/value store under
    /// `valueKeyPrefix`.
    public static func createSpace(
        values: [String: Any] = [:]
    ) -> SpaceID? {
        let op = make(
            "SpaceCreateOperation",
            initializer: "initWithOptions:values:"
        ) { instance, selector in
            sender(as: InitOptionsObjectFn.self)?(
                instance,
                selector,
                0,
                namespaced(values)
            )
        }
        return field("spaceID", of: performSync(op))
    }

    /// Destroys a Desktop. Its windows migrate to another
    /// Desktop — Mission Control's own close semantics, verified
    /// on device (#889 item 1) — so nothing is lost, but the
    /// caller decides whether that migration is what the user
    /// asked for.
    public static func destroySpace(_ space: SpaceID) -> Bool {
        let op = make(
            "SpaceDestroyOperation",
            initializer: "initWithSpaceID:"
        ) { instance, selector in
            sender(as: InitIDFn.self)?(instance, selector, space)
        }
        return performAsync(op)
    }

    /// Renames a Desktop. Verify by `name(of:)`.
    public static func setName(
        _ name: String,
        of space: SpaceID
    ) -> Bool {
        let op = make(
            "SpaceSetNameOperation",
            initializer: "initWithSpaceID:name:"
        ) { instance, selector in
            sender(as: InitIDObjectFn.self)?(
                instance,
                selector,
                space,
                name as NSString
            )
        }
        return performAsync(op)
    }

    /// Merges `values` into the Desktop's store, every key under
    /// `valueKeyPrefix`. Survives
    /// logout, the separate-Spaces mode flip and cable cycles on
    /// the MAIN display's Desktops (#889 item 3) — but a
    /// secondary display's Desktop is discarded with its display
    /// on unplug, values included (item 4), so stamping alone
    /// cannot carry that identity across a replug.
    public static func setValues(
        _ values: [String: Any],
        of space: SpaceID
    ) -> Bool {
        let op = make(
            "SpaceSetValuesOperation",
            initializer: "initWithSpaceID:values:"
        ) { instance, selector in
            sender(as: InitIDObjectFn.self)?(
                instance,
                selector,
                space,
                namespaced(values)
            )
        }
        return performAsync(op)
    }
}
