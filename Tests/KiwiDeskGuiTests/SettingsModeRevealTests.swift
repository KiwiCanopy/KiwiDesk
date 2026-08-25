import Foundation
import Testing

@testable import KiwiDesk

/// The mode-reveal timeline's contract (#760): only the EXPLICIT
/// segment flip into Power User washes, the implicit
/// `ensureModeAdmits` promotion and the way back to Simple stay
/// silent, and the wash always clears itself. The chrome half —
/// where the wash paints and which stroke it pairs with — is
/// `ModeGatedChromeTests`.
@MainActor
@Suite("Settings mode reveal")
struct SettingsModeRevealTests {
    private func model() -> SettingsModel {
        let name = "settings-mode-reveal-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return makeTestModel(defaults: defaults)
    }

    /// Awaits the reveal's own completion signal rather than
    /// polling for its effect — tests.md ▸ Async tests argues
    /// that measurement once. The fact local to this wait: its
    /// bound went 30 s → 120 s on 2026-08-09 and then timed out
    /// at 120 s anyway, because the clear runs on the main
    /// actor and the deadline was really measuring how long the
    /// scan-heavy suites held it.
    ///
    /// With no deadline, a timeline that never completed would
    /// stall the job rather than name an assertion — `Tests/`
    /// has no `.timeLimit` precedent, so this is the trade
    /// `SocketServerTests` already makes. It is a safe one
    /// here: the timeline is a `Task.sleep` over a fixed hold.
    ///
    /// Call it ONLY after a flip that reveals — `modeRevealTask`
    /// is not an in-flight predicate, and its own doc says what
    /// that costs a caller who reads it elsewhere. The non-nil
    /// assertion is what stops `await nil?.value` from passing
    /// instantly on a timeline that was never scheduled.
    private func awaitCleared(_ model: SettingsModel) async {
        let timeline = model.modeRevealTask
        #expect(timeline != nil, "the flip scheduled no reveal")
        await timeline?.value
        #expect(!model.modeRevealActive)
    }

    @Test("the explicit flip washes, then clears itself")
    func explicitFlipWashesAndClears() async {
        let model = model()
        model.flipSettingsMode(.powerUser, reduceMotion: false)
        #expect(model.settingsMode == .powerUser)
        #expect(model.modeRevealActive)
        await awaitCleared(model)
    }

    /// Reduce Motion keeps the affordance — the wash still shows
    /// (flat, its hold absorbing the dropped fade) and still
    /// clears. Dropping it entirely would take the "what
    /// changed" answer from exactly the users who also lose the
    /// reflow (ui-designer, 2026-08-09).
    @Test("Reduce Motion still washes, and still clears")
    func reduceMotionStillWashes() async {
        let model = model()
        model.flipSettingsMode(.powerUser, reduceMotion: true)
        #expect(model.modeRevealActive)
        await awaitCleared(model)
    }

    @Test("the way back to Simple never washes")
    func flipBackIsSilent() {
        let model = model()
        model.setSettingsMode(.powerUser)
        model.flipSettingsMode(.simple, reduceMotion: false)
        #expect(model.settingsMode == .simple)
        #expect(!model.modeRevealActive)
    }

    @Test("flipping away ends a running wash outright")
    func flipAwayEndsTheWash() {
        let model = model()
        model.flipSettingsMode(.powerUser, reduceMotion: false)
        #expect(model.modeRevealActive)
        model.flipSettingsMode(.simple, reduceMotion: false)
        #expect(!model.modeRevealActive)
    }

    @Test("a flip to the mode already picked never washes")
    func redundantFlipIsSilent() {
        let model = model()
        model.setSettingsMode(.powerUser)
        model.flipSettingsMode(.powerUser, reduceMotion: false)
        #expect(!model.modeRevealActive)
    }

    /// The implicit promotion — navigation or search landing in
    /// a Power-User-only area — goes through `setSettingsMode`
    /// and stays silent: search owns that landing's wash, and a
    /// second one would dilute the target the user asked for.
    @Test("the implicit promotion never washes")
    func promotionIsSilent() {
        let model = model()
        model.setSettingsMode(.powerUser)
        #expect(model.settingsMode == .powerUser)
        #expect(!model.modeRevealActive)
    }

    /// A newer flip supersedes the running timeline rather than
    /// racing it: the second wash keeps its own full window, and
    /// the first task's clear must not land inside it early.
    /// The superseded handle is captured and awaited FIRST,
    /// which is what makes the contract observable at all.
    /// Sampling only once the NEWEST timeline has finished
    /// cannot tell a cancelled predecessor from one that ran
    /// and cleared the wash under it — by then both have
    /// written the same `false`, and the suite stays green with
    /// the supersede machinery removed, which is the only
    /// reason the handle is stored.
    ///
    /// **The superseded handle is inspected, never awaited.**
    /// A draft did `await superseded?.value` and then asserted
    /// the wash was still up, which reads as the stronger
    /// check and is the same defect #979 is about, one level
    /// in: both timelines are queued on the main actor, so
    /// under a starved full run the cancelled one and the live
    /// one resume together and the live one has already
    /// cleared the wash by the time the await returns. It
    /// passed alone and failed in a 3877-test run at 73 s.
    /// `isCancelled` is the same fact read synchronously, with
    /// no suspension point to race across.
    ///
    /// What this can and cannot catch, measured rather than
    /// assumed (guard-prover): removing BOTH `cancel()` calls
    /// reds it. Removing either one alone does not, and that is
    /// not a hole — `flipSettingsMode` is the one writer of the
    /// handle, so the flip-away branch leaves the reveal's task
    /// in place for the next reveal's cancel to reach, and vice
    /// versa. Either call alone is sufficient today; no test at
    /// this altitude can tell them apart.
    @Test("a rapid re-flip keeps the newest wash its window")
    func rapidReflipSupersedes() async {
        let model = model()
        model.flipSettingsMode(.powerUser, reduceMotion: false)
        let superseded = model.modeRevealTask
        #expect(superseded != nil)
        model.flipSettingsMode(.simple, reduceMotion: false)
        model.flipSettingsMode(.powerUser, reduceMotion: false)
        #expect(model.modeRevealActive)
        #expect(superseded?.isCancelled == true)
        // Not a supersede assertion — a fresh task is stored
        // whether or not the old one was cancelled, so nothing
        // in `flipSettingsMode` reds this (guard-prover). It
        // guards the WAIT that follows: `awaitCleared` reads
        // the handle again, and if the third flip had scheduled
        // nothing it would await this finished predecessor and
        // assert on an already-cleared wash — the staleness
        // `modeRevealTask`'s own doc warns about.
        #expect(model.modeRevealTask != superseded)
        await awaitCleared(model)
    }
}
