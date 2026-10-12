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

    /// The apps the Tile picker offers (#2071): those with a window
    /// floating on a guess now, then those the guess floated a
    /// window of earlier this session, each by recency. `titles`
    /// are the open guessed windows', empty for a remembered app.
    public func guessedFloatApps() -> [GuessedFloatApp] {
        var open: [String: [String]] = [:]
        for window in state.windows.all
        where tileRefusal(of: window.id)?.isGuess == true {
            guard let app = window.appBundleID?.lowercased() else {
                continue
            }
            open[app, default: []].append(window.title)
        }
        let apps = eventLoop.guessedApps.entries.map {
            GuessedFloatApp(
                bundleID: $0.bundleID,
                name: $0.name,
                titles: open[$0.bundleID] ?? []
            )
        }
        // Live but unrecorded only after the cap evicted it.
        let unseen = open.keys.filter { app in
            !apps.contains { $0.bundleID == app }
        }
        let live = unseen.sorted().map { app in
            GuessedFloatApp(
                bundleID: app,
                name: state.windows.all.first {
                    $0.appBundleID?.lowercased() == app
                }?.appName ?? app,
                titles: open[app] ?? []
            )
        }
        return apps.filter { !$0.titles.isEmpty } + live
            + apps.filter { $0.titles.isEmpty }
    }

    /// Whether a tracked window of `app` floats on a guess — where
    /// a bar menu's App Rules… lands (#2173).
    public func floatsOnGuess(app: String) -> Bool {
        guessedFloatApps().contains {
            $0.bundleID == app.lowercased() && !$0.titles.isEmpty
        }
    }
}
