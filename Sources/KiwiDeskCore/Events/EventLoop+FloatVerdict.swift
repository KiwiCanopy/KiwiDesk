import AppKit
import ApplicationServices

/// The automatic float verdict (#1810): the force-float reason
/// first, else detection over one window's `WindowFacts` (#1883).
extension EventLoop {
    /// Where detection's half of a verdict comes from: facts
    /// already read, the element — read through `WindowFacts` only
    /// where nothing forces the float — or what an off-main read
    /// found (#1933).
    enum FloatDetectionSource {
        case facts(WindowFacts)
        case element(AXUIElement, layer: Int?)
        case read(AutoFloatReason?)
    }

    /// The automatic verdict for one tracked window (#1810) — the
    /// one composition `track` and `recheckFloat` both take — and
    /// the one place `guessedApps` learns an app (#2071).
    func autoFloatVerdict(
        _ source: FloatDetectionSource,
        id: WindowID,
        pid: pid_t,
        bundleID: String?
    ) -> FloatVerdict {
        let verdict = Self.composeVerdict(
            source,
            pid: pid,
            activationPolicy: policy(of: pid),
            tilesAsOwnWindow: tilesAsOwnWindow(pid: pid, id: id),
            bundleID: bundleID,
            rules: floatRules
        )
        noteGuess(verdict, id: id, pid: pid, bundleID: bundleID)
        return verdict
    }

    /// Files the app where the guess floats the window, or would
    /// were it not escaped: no Dock icon is read whatever the
    /// rules; a fixed size only where the guess asked (#2071).
    private func noteGuess(
        _ verdict: FloatVerdict,
        id: WindowID,
        pid: pid_t,
        bundleID: String?
    ) {
        guard let bundleID,
            forceFloatReason(pid: pid, id: id)?.isGuess == true
                || verdict.reason?.isGuess == true
        else { return }
        guessedApps.note(bundleID: bundleID, name: appRef(of: pid).name)
    }

    /// Forgets the verdict of every tracked window of an app whose
    /// guess changed from `old`, so its next recheck judges a fixed
    /// size as at adoption (#2173).
    func rejudgeGuesses(from old: FloatGuess) {
        for (pid, windows) in elements {
            let app = appRef(of: pid).bundleID
            guard old.applies(to: app) != floatRules.guess.applies(to: app)
            else { continue }
            for id in windows.keys { detectedFloating[id] = nil }
        }
    }

    /// `autoFloatVerdict` over the app's policy and the own-window
    /// mark as read, pure where the source is: a forced float asks
    /// detection nothing (#1883 replays dumps through it).
    nonisolated static func composeVerdict(
        _ source: FloatDetectionSource,
        pid: pid_t,
        activationPolicy: NSApplication.ActivationPolicy,
        tilesAsOwnWindow: Bool,
        bundleID: String?,
        rules: FloatRules
    ) -> FloatVerdict {
        if let forced = forceFloatReason(
            pid: pid,
            activationPolicy: activationPolicy,
            tilesAsOwnWindow: tilesAsOwnWindow
        ), forced != .accessoryApp || rules.guess.applies(to: bundleID) {
            return .floats(forced)
        }
        let facts: WindowFacts
        switch source {
        case .facts(let read):
            facts = read
        case .element(let element, let layer):
            facts = WindowFacts.read(element, layer: layer)
        case .read(let reason):
            return FloatVerdict(reason)
        }
        return FloatVerdict(
            FloatDetection.autoFloatReason(
                facts,
                bundleID: bundleID,
                rules: rules
            )
        )
    }
}
