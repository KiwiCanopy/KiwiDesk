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
    private(set) var baseline: KiwiCore.ShelfPaintBaseline?

    var tilingSettings: () -> TilingSettings = { TilingSettings() }
    /// Whether Settings holds an unsaved draft, whose Save would
    /// overwrite a pick here.
    var settingsDraftPending: () -> Bool = { false }
    var captureBaseline: () -> KiwiCore.ShelfPaintBaseline? = { nil }
    /// Whether a baseline still describes the live profile; one
    /// that does not is re-captured by the next pick.
    var baselineIsLive: (KiwiCore.ShelfPaintBaseline) -> Bool = { _ in
        true
    }
    /// Sets every bar's visibility live and into the live profile
    /// (`KiwiCore.setBarVisibility`).
    var onSetVisibility: (ShelfVisibility) -> Void = { _ in }
    /// Returns whether the restore landed; it is refused once
    /// another profile went live (`KiwiCore.restoreBarVisibility`).
    var onRestore: (KiwiCore.ShelfPaintBaseline) -> Bool = { _ in false }
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

    /// A pick that would change nothing writes nothing, so Revert
    /// stays greyed until something changed.
    func pick(_ visibility: ShelfVisibility) {
        guard !settingsDraftPending() else { return }
        let live = tilingSettings()
        var next = live
        next.setEveryBarVisibility(visibility)
        guard next != live else { return }
        if baseline.map(baselineIsLive) != true {
            baseline = captureBaseline()
        }
        onSetVisibility(visibility)
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
