import AppKit
import ApplicationServices

/// WindowServer-side window queries — no AX, one
/// `CGWindowListCopyWindowInfo` snapshot each (~1 ms), never
/// called in a loop. Here rather than in `Events/` because the
/// §1 subsystem map gives WindowServer queries to `AX/` (#662).
extension AXHelper {
    /// Counts an app's normal (layer-0) document windows via the
    /// WindowServer. `.excludeDesktopElements` plus the layer==0
    /// filter drop Finder's desktop / wallpaper / icon surfaces,
    /// so only real document windows count. `onScreenOnly`
    /// restricts to windows on a currently-visible space across
    /// ALL displays — the signal for "activating this app won't
    /// switch Spaces" (an off-screen-only app teleports on
    /// activate).
    public static func normalWindowCount(
        pid: pid_t,
        onScreenOnly: Bool
    ) -> Int {
        let options: CGWindowListOption =
            onScreenOnly
            ? [.optionOnScreenOnly, .excludeDesktopElements]
            : [.optionAll, .excludeDesktopElements]
        return normalWindowOwners(options: options)
            .count { $0 == pid }
    }

    /// PIDs owning at least one normal (layer-0) document window
    /// — the all-pids sibling of `normalWindowCount`, same
    /// options, same layer filter. The boot scan's
    /// windowless-app prefilter (#662, #672).
    public static func pidsWithNormalWindows() -> Set<pid_t> {
        Set(
            normalWindowOwners(
                options: [.optionAll, .excludeDesktopElements]
            )
        )
    }

    /// One owner pid per normal (layer-0) window in the
    /// snapshot, repeats included so the count query stays a
    /// count.
    private static func normalWindowOwners(
        options: CGWindowListOption
    ) -> [pid_t] {
        guard
            let list = CGWindowListCopyWindowInfo(
                options,
                kCGNullWindowID
            ) as? [[String: Any]]
        else { return [] }
        return list.compactMap { info in
            guard
                let pid =
                    (info[kCGWindowOwnerPID as String]
                    as? NSNumber)?.int32Value,
                let layer =
                    (info[kCGWindowLayer as String]
                    as? NSNumber)?.intValue,
                layer == 0
            else { return nil }
            return pid
        }
    }
}
