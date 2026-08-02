import AppKit
import ApplicationServices

/// WindowServer-side window queries — no AX, one
/// `CGWindowListCopyWindowInfo` snapshot each. Here rather than
/// in `Events/` because the §1 subsystem map gives WindowServer
/// queries to `AX/` (#662).
///
/// Keep the census queries out of loops (~1 ms each). The one
/// deliberate exception is `onScreenStackingOrder`, which the
/// z-order drain polls; its own doc carries the measured cost and
/// the argument.
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

    /// The front-to-back stacking of the normal (layer-0) windows
    /// on the currently visible spaces — the WindowServer's own
    /// answer to "which window is really on top", which is the
    /// only thing that can tell whether a raise has landed yet
    /// (#684): the AX call returns before the app performs it.
    ///
    /// `WindowID.raw` IS the `CGWindowID` this list is keyed by,
    /// so no lookup is needed to compare it against a raise order.
    ///
    /// The one query here that IS polled — the z-order drain reads
    /// it every 5 ms while waiting for a raise to land — which the
    /// measured ~0.4 ms per snapshot is what pays for.
    public static func onScreenStackingOrder() -> [WindowID] {
        guard
            let list = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID
            ) as? [[String: Any]]
        else { return [] }
        return list.compactMap { info in
            guard
                (info[kCGWindowLayer as String] as? NSNumber)?
                    .intValue == 0,
                let raw =
                    (info[kCGWindowNumber as String] as? NSNumber)?
                    .uint32Value
            else { return nil }
            return WindowID(raw)
        }
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
