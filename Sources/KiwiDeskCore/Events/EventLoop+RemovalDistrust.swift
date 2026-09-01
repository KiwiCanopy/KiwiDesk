import ApplicationServices

/// The removal-distrust gate (#1157). Under fast focus churn a
/// lazy-AX app (Electron-class) transiently UNDER-reports its
/// window list, and the sweep read that absence as a close — the
/// window lost its slot, the close-return raise fired, and only
/// the ~20 s adoption heal brought it back. The gate is #913's
/// mirror image: there the AX list over-reports a hidden app's
/// windows and `appIsHidden` is the truth; here it under-reports
/// a live one, and the WindowServer's on-screen census is. The
/// asymmetry is deliberate and one-way — the census may REFUSE a
/// removal (a listed window is composited on the current Desktop,
/// so it exists), but never cause one: it omits other-Desktop
/// windows exactly as readily as AX does, which is why #913 bars
/// it from the hide drop. Residue: the census is layer-0 only,
/// so a raised-layer or fully absent window keeps the old
/// behavior — the gate is a net, not a guarantee.
extension EventLoop {
    /// Refuses one sweep removal for a window the census still
    /// shows. The first refusal of a continuous-absence episode
    /// logs and queues a follow-up reconcile — so a TRUE close
    /// still compositing at sweep time converges on the retrack
    /// one-shot instead of waiting for the next incidental pass —
    /// while later passes of the same episode refuse silently.
    func refuseRemoval(_ id: WindowID, pid: pid_t, app: AppRef) {
        guard removalDistrusted.insert(id).inserted else { return }
        onLog(
            "close distrust: w\(id.raw) of "
                + "\(app.bundleID ?? app.name) missing from the "
                + "AX list but still on screen — removal refused"
        )
        queueRetrack(pid: pid)
    }
}
