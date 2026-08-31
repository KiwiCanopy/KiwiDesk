import Foundation

/// WindowServer desktop operations bridge extension (#26, #884).
extension WMBridge {

    /// Managed display space property list dictionary
    /// (`NativeSpaces.allSpaces()`).
    static func managedDisplaySpaces() -> [[String: Any]]? {
        let op = make(
            "CopyManagedDisplaySpacesOperation",
            initializer: "init"
        ) { instance, selector in
            sender(as: InitFn.self)?(instance, selector)
        }
        return field("propertyListArray", of: performSync(op))
    }

    /// Fetches assigned name for Space ID.
    public static func name(of space: SpaceID) -> String? {
        let op = make(
            "SpaceCopyNameOperation",
            initializer: "initWithSpaceID:"
        ) { instance, selector in
            sender(as: InitIDFn.self)?(instance, selector, space)
        }
        return field("string", of: performSync(op))
    }

    /// Reads KiwiDesk namespaced entries stored on the Desktop.
    public static func stamps(of space: SpaceID) -> [String: Any]? {
        guard let values = values(of: space) else { return nil }
        var out: [String: Any] = [:]
        for (key, value) in values where key.hasPrefix(valueKeyPrefix) {
            out[String(key.dropFirst(valueKeyPrefix.count))] = value
        }
        return out
    }

    /// Reads full property list dictionary for Space ID.
    public static func values(of space: SpaceID) -> [String: Any]? {
        let op = make(
            "SpaceCopyValuesOperation",
            initializer: "initWithSpaceID:"
        ) { instance, selector in
            sender(as: InitIDFn.self)?(instance, selector, space)
        }
        return field("propertyListDictionary", of: performSync(op))
    }

    /// Sets active space on display identifier
    /// (`SLSGetActiveSpace`, #26, #1023).
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

    /// Hides windows of specified spaces from compositor
    /// (#1023, device test 2026-08-26).
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

    /// Creates managed desktop space in Mission Control (#889 item 1).
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

    /// Destroys desktop space, migrating windows (#889 item 1).
    public static func destroySpace(_ space: SpaceID) -> Bool {
        let op = make(
            "SpaceDestroyOperation",
            initializer: "initWithSpaceID:"
        ) { instance, selector in
            sender(as: InitIDFn.self)?(instance, selector, space)
        }
        return performAsync(op)
    }

    /// Renames desktop space.
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

    /// Writes custom metadata dictionary to desktop space (#889 items 3 & 4).
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
