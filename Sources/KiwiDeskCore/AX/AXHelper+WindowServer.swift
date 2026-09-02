import AppKit
import ApplicationServices

/// WindowServer window query helpers (#662).
extension AXHelper {
    /// Counts layer-0 document windows for process.
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

    /// Set of visible layer-0 document window IDs per PID (#675).
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

    /// Every layer-0 document window on ANY Desktop with its
    /// owning pid (#1146) — the id → owner map a per-Desktop
    /// census intersects its space lists with. Not a presence
    /// read: a closed window lingers here for a while (device,
    /// 2026-09-02), so "exists" is the space list's answer.
    public static func allNormalWindowOwners() -> [WindowID: pid_t] {
        guard
            let list = CGWindowListCopyWindowInfo(
                [.optionAll, .excludeDesktopElements],
                kCGNullWindowID
            ) as? [[String: Any]]
        else { return [:] }
        var owners: [WindowID: pid_t] = [:]
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
            owners[WindowID(raw)] = pid
        }
        return owners
    }

    /// PIDs owning at least one layer-0 document window (#662, #672).
    public static func pidsWithNormalWindows() -> Set<pid_t> {
        Set(
            normalWindowOwners(
                options: [.optionAll, .excludeDesktopElements]
            )
        )
    }

    /// Front-to-back stacking order across ALL visible window
    /// layers deliberately — overlays and panels interleave with
    /// layer-0 windows, and a layer-filtered read reordered them
    /// (`FloatDetection.shouldFloat`, #418, #684). Returns ids,
    /// never counts: the caller's census keys on identity.
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
