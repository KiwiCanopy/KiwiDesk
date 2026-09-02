import AppKit
import Foundation

/// Every machine touch Open or Focus makes — both branches of
/// `launch` — in one place, so a test can state the world and
/// record what the command did to it (#673).
///
/// A bundle rather than separate properties on `KiwiCore`: they
/// are one feature's seams, always substituted together, and the
/// fixture proves it — a test replaces a struct's fields instead
/// of assigning five closures. Each defaults LIVE — there is
/// no wiring step to forget, unlike the `nil`-defaulted guards
/// (`frontmostPIDProvider`), so the default IS the implementation
/// and a test overrides what it needs.
@MainActor
struct OpenOrFocusSeams {
    /// Resolves a bundle id to a running app's pid — matched on
    /// the id, not the display name, which is locale- and
    /// rename-proof (see `AppRef`). nil when the app is not
    /// running, which sends the command to LaunchServices.
    var runningAppPID: @MainActor (String) -> pid_t? = {
        bundleID in
        NSWorkspace.shared.runningApplications.first {
            $0.bundleIdentifier?.lowercased() == bundleID
        }?.processIdentifier
    }

    /// How many windows the app has up, and which are parked.
    var census: @MainActor (pid_t) -> KiwiCore.AppWindowCensus =
        KiwiCore.readAppWindowCensus

    /// Brings one parked window back.
    var deminiaturize: @MainActor (pid_t, WindowID) -> Void =
        KiwiCore.writeDeminiaturize

    /// Brings the app forward. Separate from the deminiaturize so
    /// a test can pin that the restore runs FIRST — the order is
    /// the difference between the app arriving with a window on
    /// its way up and arriving a beat behind it.
    var activate: @MainActor (pid_t) -> Void = { pid in
        NSRunningApplication(processIdentifier: pid)?.activate()
    }

    /// Launches the app — the branch taken when it is not running,
    /// or when `spawn_new` asks for a fresh instance. Returns
    /// false when LaunchServices cannot resolve the bundle id,
    /// which is the command's "app not found".
    ///
    /// Seamed for the same reason as the rest and not because
    /// #673 needs it: without it a test naming any INSTALLED
    /// bundle id launches that app for real, which is how the
    /// suite came to activate Finder on every run.
    var openApp: @MainActor (String, Bool) -> Bool = {
        bundleID,
        newInstance in
        guard
            let url = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: bundleID
            )
        else { return false }
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = newInstance
        NSWorkspace.shared.openApplication(
            at: url,
            configuration: config
        )
        return true
    }
}

/// The all-minimized arm of Open or Focus (#673).
///
/// `NSRunningApplication.activate()` brings an app forward but
/// does not take anything out of the Dock, so pressing the
/// shortcut for an app whose every window is minimized made the
/// app frontmost with nothing on screen — no visible response at
/// all. The cycle (`cycleToNextWindow`) cannot help: a minimize
/// evicts the window from state entirely.
///
/// The rule, ruled and recorded in `docs/design-decisions.md`:
/// **the shortcut never touches minimized windows while any
/// window is visible; when none are, it restores exactly one, the
/// most recently minimized.** No timer, no in-cycle unminimize —
/// a focus gesture must not undo a parking decision.
extension KiwiCore {
    /// What Open or Focus needs to know about a running app's
    /// windows: how many are up, and which are parked.
    ///
    /// Both come from ONE `kAXWindows` walk rather than from the
    /// WindowServer count `yieldFocusToDesktop` uses, and that is
    /// a correctness choice before a cost one. `.optionOnScreenOnly`
    /// omits the windows of an app **hidden** with ⌘H as readily
    /// as minimized ones, so a hidden app with three windows up
    /// and one parked reads as "nothing visible" — and the
    /// restore would then un-park a window that the following
    /// `activate()` was about to un-hide alongside its siblings,
    /// breaking the rule this file exists to keep. AX still lists
    /// a hidden app's windows, and marks only the parked ones
    /// minimized, so the two are told apart. It also spares the
    /// common press a whole-system `CGWindowListCopyWindowInfo`
    /// snapshot.
    ///
    /// What the swap gives up, deliberately: `normalWindowCount`
    /// filtered to `layer == 0` and excluded desktop elements, so
    /// only document windows counted. A raw `kAXWindows` walk
    /// counts a dialog, a sheet, an inspector or a floating
    /// palette as visible too — and that is the wanted ruling
    /// here, not an oversight. The rule is "nothing on screen",
    /// and a palette IS on screen: the press brings the app
    /// forward and the user sees something, which is the failure
    /// #673 reports. An app whose documents are all parked but
    /// whose inspector is open therefore keeps its parked windows
    /// parked.
    ///
    /// The known blind spot is the other one: a window on another
    /// native desktop is in neither list (#25), so an app with
    /// one there and one parked here reads as all-parked. That is
    /// in `docs/accepted-limitations.md`.
    struct AppWindowCensus: Sendable {
        /// Windows the app has up on this desktop — every
        /// non-minimized window AX lists, panels included.
        let visible: Int
        /// Its minimized windows, in the app's own `kAXWindows`
        /// order — which is the fallback ordering when KiwiDesk
        /// has no record of its own.
        let minimized: [WindowID]
    }

    /// The live `census`, one `kAXWindows` walk.
    @MainActor
    static func readAppWindowCensus(
        pid: pid_t
    ) -> AppWindowCensus {
        let elements = AXHelper.windows(pid: pid)
        let minimized = elements.filter(AXHelper.isMinimized)
        return AppWindowCensus(
            visible: elements.count - minimized.count,
            minimized: minimized.compactMap(AXHelper.windowID(of:))
        )
    }

    /// The live `deminiaturize`. Re-finds the element from
    /// the id — a second short walk on a press that is already
    /// reaching into the Dock, in exchange for a seam whose
    /// payload is a plain value.
    @MainActor
    static func writeDeminiaturize(pid: pid_t, id: WindowID) {
        guard
            let element = AXHelper.windows(pid: pid).first(
                where: { AXHelper.windowID(of: $0) == id }
            )
        else { return }
        AXHelper.unminimize(element)
    }

    /// Restores one window of `pid` when the app has none up.
    /// No-op otherwise, which is the common case.
    ///
    /// `bundleID` arrives lowercased (the command normalizes it)
    /// and selects the remembered window; the census is the
    /// authority on what is actually minimized right now.
    func restoreOneMinimizedIfNothingVisible(
        pid: pid_t,
        bundleID: String
    ) {
        restoreOneMinimizedIfNothingVisible(
            pid: pid,
            bundleID: bundleID,
            census: openOrFocus.census(pid)
        )
    }

    /// The same, on a census the caller already read (#1146:
    /// `launch` reads it once for the reach and the restore).
    func restoreOneMinimizedIfNothingVisible(
        pid: pid_t,
        bundleID: String,
        census: AppWindowCensus
    ) {
        guard census.visible == 0,
            let target = minimizedRestoreTarget(
                among: census.minimized,
                bundleID: bundleID
            )
        else { return }
        openOrFocus.deminiaturize(pid, target)
    }

    /// Which of an app's parked windows to bring back: the one
    /// KiwiDesk recorded as most recently minimized, if it is
    /// still parked, else the first the app lists.
    ///
    /// The record is advisory and can be absent (a fresh KiwiDesk
    /// over already-minimized windows) or stale (a window closed
    /// while minimized fires no event), so the fallback is not an
    /// edge case — it is the whole answer on a cold start.
    func minimizedRestoreTarget(
        among minimized: [WindowID],
        bundleID: String
    ) -> WindowID? {
        guard let first = minimized.first else { return nil }
        guard
            let remembered = state.lastMinimized(
                bundleID: bundleID
            ),
            minimized.contains(remembered)
        else { return first }
        return remembered
    }
}
