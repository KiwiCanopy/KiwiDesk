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

    /// Per-owner ids of on-screen normal (layer-0) document
    /// windows, from one snapshot — the adoption-heal gate's
    /// census (#675). Ids rather than counts on purpose: the
    /// tracked set legitimately holds windows this census
    /// excludes (raised-layer transient overlays, and tracking
    /// keeps other-desktop windows the on-screen list drops),
    /// so a count comparison lets one such window permanently
    /// shadow a missed document window — membership cannot be
    /// shadowed. On-screen-only deliberately, unlike the boot
    /// prefilter below: AX lists only the current desktop's
    /// windows, so counting other desktops would make the gate
    /// fire reconciles it can never satisfy. `WindowID.raw` IS
    /// the `CGWindowID` this list is keyed by.
    public static func onScreenNormalWindowIDs()
        -> [pid_t: Set<WindowID>]
    {
        guard
            let list = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID
            ) as? [[String: Any]]
        else { return [:] }
        var ids: [pid_t: Set<WindowID>] = [:]
        for info in list {
            guard
                let pid =
                    (info[kCGWindowOwnerPID as String]
                    as? NSNumber)?.int32Value,
                let layer =
                    (info[kCGWindowLayer as String]
                    as? NSNumber)?.intValue,
                layer == 0,
                let raw =
                    (info[kCGWindowNumber as String]
                    as? NSNumber)?.uint32Value
            else { continue }
            ids[pid, default: []].insert(WindowID(raw))
        }
        return ids
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

    /// The front-to-back stacking of the windows on the currently
    /// visible spaces — the WindowServer's own answer to "which
    /// window is really on top", which is the only thing that can
    /// tell whether a raise has landed yet (#684): the AX call
    /// returns before the app performs it.
    ///
    /// **Every layer, deliberately**, unlike the census queries
    /// below. `FloatDetection.shouldFloat(role:subrole:layer:)`
    /// floats a window *because* its layer is non-zero — panels
    /// and overlays sit at layer 3 — so a layer-0 filter would
    /// hide exactly the float targets the #418 raise exists to
    /// lift, and the plan would drop each one as "not on screen"
    /// and never raise it again. Windows above layer 0 are also
    /// genuinely above the tiled plane by compositor level, so
    /// including them makes the diff read that correctly instead
    /// of re-raising them forever.
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
