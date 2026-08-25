import Foundation

/// The Desktop half of the bridge: which Desktop a display
/// shows and switching it (#26), the Desktop lifecycle, names,
/// and the per-Desktop key/value store. Every id is a
/// WindowServer space id — a Desktop or a fullscreen space,
/// never a KiwiDesk space, which the WindowServer knows nothing
/// about (#884's semantics note).
extension WMBridge {
    // MARK: - Reads

    /// Every managed display's identifier — a per-display UUID
    /// with "Displays have separate Spaces" on, the synthetic
    /// `"Main"` in shared mode. The representation changes with
    /// the mode (#889); never assume one shape.
    ///
    /// Read off the display/spaces model rather than through
    /// `CopyManagedDisplaysOperation`, which performs and answers
    /// nil on 26.6.1 (observed 2026-08-25) — the same
    /// success-shaped decline as edge reservation, on a read.
    public static func managedDisplays() -> [String]? {
        managedDisplaySpaces()?.compactMap {
            $0["Display Identifier"] as? String
        }
    }

    /// The full display/spaces model as the WindowServer holds
    /// it — the same plist `SLSCopyManagedDisplaySpaces` returns,
    /// through the bridge. `NativeSpaces.allSpaces()` keeps the
    /// C symbol; this read exists so a consumer of the bridge can
    /// verify its own writes against ONE source.
    public static func managedDisplaySpaces() -> [[String: Any]]? {
        let op = make(
            "CopyManagedDisplaySpacesOperation",
            initializer: "init"
        ) { instance, selector in
            sender(as: InitFn.self)?(instance, selector)
        }
        return field("propertyListArray", of: performSync(op))
    }

    /// The space `displayIdentifier` currently shows.
    public static func currentSpace(
        displayIdentifier: String
    ) -> SpaceID? {
        let op = make(
            "ManagedDisplayGetCurrentSpaceOperation",
            initializer: "initWithDisplayIdentifier:"
        ) { instance, selector in
            sender(as: InitObjectFn.self)?(
                instance,
                selector,
                displayIdentifier as NSString
            )
        }
        return field("spaceID", of: performSync(op))
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

    /// The Desktop's key/value store — the WindowServer's own
    /// dictionary (`type`, `id64`, `uuid`, Apple's
    /// `WindowManagerInfo`, …) with any custom keys beside them.
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

    /// Switches `displayIdentifier` to `space` (#26). Verify by
    /// `currentSpace(displayIdentifier:)`.
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

    /// Creates a real managed Desktop — it joins Mission
    /// Control's user list (#889 item 1) — and returns its id.
    /// `values` seeds its key/value store; custom keys are
    /// namespaced (`kiwidesk.*`) because they land in Apple's
    /// own dictionary.
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
                values as NSDictionary
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

    /// Merges `values` into the Desktop's store. Survives
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
                values as NSDictionary
            )
        }
        return performAsync(op)
    }
}
