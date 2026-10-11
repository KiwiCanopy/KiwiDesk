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
    /// forgets the verdicts of every app it reaches, so their next
    /// recheck judges them as at adoption — the float flag and the
    /// overlay flag with them.
    func installFloatRules(_ rules: FloatRules) {
        let old = eventLoop.floatRules.guess
        eventLoop.floatRules = rules
        guard old != rules.guess else { return }
        eventLoop.rejudgeGuesses(from: old)
    }
}
