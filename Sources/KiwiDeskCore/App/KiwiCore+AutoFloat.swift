import ApplicationServices
import Foundation

/// The escape for automatic floats (#2173): `float_automatically`
/// and `tile_rules` decide where detection may float a window on a
/// guess. Both resolve with the window rules into
/// `EventLoop.floatRules.guess`.
extension KiwiCore {
    /// `set_float_automatically`: writes the BASE, so a profile's
    /// own override still wins, and lasts until the next config
    /// load. Inside a load it writes the base alone, since the
    /// load's tail resolves every family.
    func setFloatAutomatically(_ args: [JSONValue]) -> CommandResponse {
        guard let enabled = args.first?.boolValue else {
            return .fail("expected boolean")
        }
        globalRuleBase.floatAutomatically = enabled
        guard !defersWindowRuleReconcile else { return .ok() }
        let live = eventLoop.floatRules
        installFloatRules(
            FloatRules(
                live.rawRules,
                guess: globalRuleBase.guess(tileRules: live.guess.tileRules)
            )
        )
        if mayReconcileWindowRulesNow { eventLoop.reconcileAll() }
        return .ok()
    }

    /// The one writer of `EventLoop.floatRules`. A changed guess
    /// re-judges the windows of every app it reaches as at adoption
    /// and re-derives their overlay flag, since a Tile rule tiles a
    /// window its app's missing Dock icon would float.
    func installFloatRules(_ rules: FloatRules) {
        let old = eventLoop.floatRules.guess
        eventLoop.floatRules = rules
        guard old != rules.guess else { return }
        eventLoop.rejudgeGuesses(from: old)
        refreshGuessedOverlays()
    }

    /// A Dock-less app's windows are overlays — no ring, no bar row
    /// (#300) — only while a guess may float them; a dialog, panel
    /// or raised-layer window stays one whatever the guess.
    func refreshGuessedOverlays() {
        let guess = eventLoop.floatRules.guess
        for window in state.windows.all
        where eventLoop.classifiesAsOverlay(pid: window.pid) {
            let structural =
                window.isRaisedLayer
                || (window.subrole.map { !$0.isEmpty } == true
                    && window.subrole != kAXStandardWindowSubrole)
            let overlay = structural || guess.applies(to: window.appBundleID)
            guard window.isTransientOverlay != overlay else { continue }
            state.windows.setTransientOverlay(window.id, overlay)
        }
    }
}
