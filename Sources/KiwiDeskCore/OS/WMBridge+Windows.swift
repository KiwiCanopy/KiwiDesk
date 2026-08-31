import Foundation

/// Private WindowServer bridge operations for window space movement
/// (#25, #884).
extension WMBridge {
    /// Moves windows to target space asynchronously (#25, #884).
    public static func moveWindows(
        _ windows: [WindowID],
        to space: SpaceID
    ) -> Bool {
        let op = make(
            "MoveWindowsToManagedSpaceOperation",
            initializer: "initWithWindows:spaceID:"
        ) { instance, selector in
            sender(as: InitObjectIDFn.self)?(
                instance,
                selector,
                numbers(windows),
                space
            )
        }
        return performAsync(op)
    }

    /// Adds windows to spaces without removing from current space
    /// (#889 item 5).
    public static func addWindows(
        _ windows: [WindowID],
        to spaces: [SpaceID]
    ) -> Bool {
        membership(
            "AddWindowsToSpacesOperation",
            windows,
            spaces
        )
    }

    /// Removes windows from spaces (#889 item 5).
    public static func removeWindows(
        _ windows: [WindowID],
        from spaces: [SpaceID]
    ) -> Bool {
        membership(
            "RemoveWindowsFromSpacesOperation",
            windows,
            spaces
        )
    }

    /// Space membership query option mask (#889 item 5).
    private static let membershipOptions: UInt32 = 7

    /// Queries primary space membership for windows (#889 item 5).
    public static func spaces(for windows: [WindowID]) -> [SpaceID]? {
        let op = make(
            "CopySpacesForWindowsOperation",
            initializer: "initWithOptions:windows:"
        ) { instance, selector in
            sender(as: InitOptionsObjectFn.self)?(
                instance,
                selector,
                membershipOptions,
                numbers(windows)
            )
        }
        let ids: [NSNumber]? = field("numbers", of: performSync(op))
        return ids?.map(\.uint64Value)
    }

    private static func membership(
        _ operation: String,
        _ windows: [WindowID],
        _ spaces: [SpaceID]
    ) -> Bool {
        let op = make(operation, initializer: "initWithWindows:spaces:") {
            instance,
            selector in
            sender(as: InitObjectObjectFn.self)?(
                instance,
                selector,
                numbers(windows),
                spaces.map { NSNumber(value: $0) } as NSArray
            )
        }
        return performAsync(op)
    }

    private static func numbers(_ windows: [WindowID]) -> NSArray {
        windows.map { NSNumber(value: $0.raw) } as NSArray
    }
}
