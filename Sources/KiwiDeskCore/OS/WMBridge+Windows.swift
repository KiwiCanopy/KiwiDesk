import Foundation

/// The window half of the bridge: moving windows between
/// Desktops (#25) and the sticky primitive — a window that is a
/// member of several Desktops at once. Windows are
/// WindowServer ids (`WindowID.raw`); any app's windows, not
/// only KiwiDesk's own.
extension WMBridge {
    /// Moves `windows` to `space` — the #25 move, device-proven
    /// on another app's window (#884). A window that lands on
    /// an off-screen Desktop goes dark to Accessibility until
    /// that Desktop shows, so a caller wanting it in a KiwiDesk
    /// space keeps a pending assignment for the reveal
    /// reconcile (#884's semantics note).
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

    /// Adds `windows` to every one of `spaces` without removing
    /// them from where they are — the sticky primitive, proven
    /// visually (#889 item 5): after the add the window IS on
    /// screen on the other Desktop. Membership is tracked by the
    /// CALLER: `spaces(for:)` never reports it (same item).
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

    /// Removes `windows` from `spaces`; the counterpart of
    /// `addWindows(_:to:)`.
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

    /// The spaces `windows` belong to, as the bridge reports
    /// them. **Single membership only**: under every option mask
    /// tried (0–3 empty, 5 and 7 one id) this never lists a
    /// second Desktop a sticky add put the window on (#889
    /// item 5). Use it for the primary Desktop; keep sticky
    /// bookkeeping in KiwiDesk's own state.
    public static func spaces(
        for windows: [WindowID],
        options: UInt32 = 7
    ) -> [SpaceID]? {
        let op = make(
            "CopySpacesForWindowsOperation",
            initializer: "initWithOptions:windows:"
        ) { instance, selector in
            sender(as: InitOptionsObjectFn.self)?(
                instance,
                selector,
                options,
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
