import KiwiDeskCore
import SwiftUI

/// The tour's bars step (#2515): one choice for when every bar
/// shows, written through Core's door like the looks step's paint
/// (#1720) and reverted on the visibility leaves alone. Marks are
/// computed from the live settings, never stored (#757).
@MainActor
@Observable
final class OnboardingBarsModel {
    /// Bumped by every pick and revert, and when a window becomes
    /// key, so the step re-reads the live settings and the draft.
    private(set) var revision = 0
    /// The settings before this presentation's first pick; nil
    /// until one lands, so a step left untouched writes nothing.
    private(set) var baseline: KiwiCore.TourBaseline?

    var tilingSettings: () -> TilingSettings = { TilingSettings() }
    /// Whether Settings holds an unsaved draft, whose Save would
    /// overwrite a pick here.
    var settingsDraftPending: () -> Bool = { false }
    var captureBaseline: () -> KiwiCore.TourBaseline? = { nil }
    /// Whether a baseline still describes the live profile; one
    /// that does not is re-captured by the next pick.
    var baselineIsLive: (KiwiCore.TourBaseline) -> Bool = { _ in
        true
    }
    /// Sets every bar's visibility live and into the live profile,
    /// false where nothing changed (`KiwiCore.setBarVisibility`).
    var onSetVisibility: (ShelfVisibility) -> Bool = { _ in false }
    /// Returns whether the restore landed; it is refused once
    /// another profile went live (`KiwiCore.restoreBarVisibility`).
    var onRestore: (KiwiCore.TourBaseline) -> Bool = { _ in false }
    /// The show/hide shortcut rows, read from the live layer; a
    /// bar with no chord has no row.
    var revealKeys: () -> [OnboardingKeyFamily] = { [] }

    /// The visibility every bar shares, nil while they differ.
    var selected: ShelfVisibility? {
        _ = revision
        return tilingSettings().uniformBarVisibility
    }

    var blocked: Bool {
        _ = revision
        return settingsDraftPending()
    }

    var hasChanges: Bool {
        _ = revision
        return baseline.map(baselineIsLive) ?? false
    }

    /// Core answers whether a pick changed anything; one that
    /// did not keeps no baseline, so Revert stays greyed.
    func pick(_ visibility: ShelfVisibility) {
        guard !settingsDraftPending() else { return }
        let kept = baseline.flatMap { baselineIsLive($0) ? $0 : nil }
        let before = kept ?? captureBaseline()
        guard onSetVisibility(visibility) else { return }
        baseline = before
        revision += 1
    }

    /// Puts back the visibilities the step's first pick replaced.
    func revert() {
        guard let baseline, !settingsDraftPending() else { return }
        if onRestore(baseline) { self.baseline = nil }
        revision += 1
    }

    func refresh() {
        revision += 1
    }

    /// A new presentation starts without a baseline.
    func reset() {
        baseline = nil
    }
}
