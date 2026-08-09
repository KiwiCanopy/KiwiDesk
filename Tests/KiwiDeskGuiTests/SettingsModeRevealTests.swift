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

    /// One generous hang-guard, never a tight deadline (#344),
    /// sized for THIS wait's observed worst case: heavy
    /// synchronous `@MainActor` suites (the source scans) back
    /// the main actor up past 30 s in a full run — a 30 s
    /// guard here failed three tests whose timeline is 0.3 s
    /// (2026-08-09) — so the bound is 120 s. The poll exits
    /// the instant the clear lands; the deadline only bounds a
    /// genuine hang (a timeline that stops completing must
    /// fail the run, not wedge it).
    private func awaitCleared(
        _ model: SettingsModel
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(120)
        while Date() < deadline {
            if !model.modeRevealActive { return true }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return false
    }

    @Test("the explicit flip washes, then clears itself")
    func explicitFlipWashesAndClears() async {
        let model = model()
        model.flipSettingsMode(.powerUser, reduceMotion: false)
        #expect(model.settingsMode == .powerUser)
        #expect(model.modeRevealActive)
        #expect(await awaitCleared(model))
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
        #expect(await awaitCleared(model))
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
    @Test("a rapid re-flip keeps the newest wash its window")
    func rapidReflipSupersedes() async {
        let model = model()
        model.flipSettingsMode(.powerUser, reduceMotion: false)
        model.flipSettingsMode(.simple, reduceMotion: false)
        model.flipSettingsMode(.powerUser, reduceMotion: false)
        #expect(model.modeRevealActive)
        #expect(await awaitCleared(model))
    }
}
