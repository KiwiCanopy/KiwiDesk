import KiwiDeskCore
import SwiftUI

/// One seeded space, as the tour's spaces step draws it.
struct OnboardingSpaceCard: Identifiable, Equatable {
    let id: String
    let mode: LayoutMode
    /// The screen name it sits on, or nil if not connected (never in inches,
    /// which EDID lies about).
    let screen: String?
}

/// View state for the first-launch tour.
@MainActor
@Observable
final class OnboardingModel {
    /// Onboarding tour steps (#678, #828, #888, #1720).
    enum Step: Equatable, CaseIterable {
        case grant
        case spaces
        case looks
        case keys
        case done

        /// The one place closing beats are enumerated; the close seam
        /// asks `reachedEnd`, never a list of cases of its own.
        var isClosingBeat: Bool {
            switch self {
            case .grant, .spaces, .looks: false
            case .keys, .done: true
            }
        }
    }

    /// Current step, updated via `beginPresentation(at:)` and `advance()`
    /// (#331, #828).
    private(set) var step: Step = .grant {
        didSet {
            if step.isClosingBeat { reachedEnd = true }
        }
    }
    var isTrusted = false
    /// Boot progress seeded and kept current by `AppDelegate` (#802).
    var bootPhase: BootPhase = .ready
    /// Closing card "open at login" checkbox state (#342).
    var openAtLogin = true

    /// Ordered steps for the current tour presentation (#828).
    private(set) var plannedSteps: [Step] = []

    /// Sets initial `step` and resolves `plannedSteps` for this presentation.
    func beginPresentation(at step: Step) {
        self.step = step
        looksBaseline = nil
        plannedSteps = OnboardingEntry.plannedSteps(from: step)
    }

    /// Zero-based index of current step in `plannedSteps`.
    var progressIndex: Int? {
        plannedSteps.firstIndex(of: step)
    }

    /// Whether the tour reached a closing beat (HomeSurfacingTests).
    private(set) var reachedEnd = false

    /// Clears the `reachedEnd` flag between presentations.
    func clearReachedEnd() {
        reachedEnd = false
    }

    /// Registers/unregisters the login item to match `openAtLogin`.
    /// Wired to `LoginItemManager`; a no-op stub keeps the model
    /// testable without touching `SMAppService`.
    var onSetLoginItem: (Bool) -> Void = { _ in }
    var onOpenSettings: () -> Void = {}
    /// The closing page's ONE exit (#1365): ends the tour inside
    /// Settings, at the Mac Checklist — the card reaches a new
    /// user only if the tour hands them to it.
    var onFinish: () -> Void = {}
    /// The seeded spaces, in order, each with its layout and the
    /// screen it landed on.
    var starterSpaces: () -> [OnboardingSpaceCard] = { [] }
    /// The starter setup's title; read per render, since the seed
    /// lands after a first run's tour is wired (#1662).
    var starterTitle: () -> StarterTitle? = { nil }
    /// The live tuning the schematics draw, so the picture on day
    /// one is the picture Settings shows.
    var tilingSettings: () -> TilingSettings = { TilingSettings() }
    /// The chord families the keys step teaches, read from the
    /// live layer.
    var keyFamilies: () -> [OnboardingKeyFamily] = { [] }

    // MARK: - Looks step (#1720)

    /// Bumped by every paint and revert, and when a window becomes
    /// key, so the step re-reads the live settings and the draft.
    private(set) var looksRevision = 0
    /// The settings before this presentation's first paint; nil
    /// until one lands, so a step left untouched writes nothing.
    private(set) var looksBaseline: KiwiCore.ShelfPaintBaseline?
    /// The bundled looks, then every palette a look may name.
    var shelfLooks: () -> [ShelfLook] = { [] }
    var shelfPalettes: () -> [ColorPalette] = { [] }
    /// The live Space labels the look pictures draw.
    var spaceLabels: () -> [SpaceGlyph] = { [] }
    /// Whether Settings holds an unsaved draft, whose Save would
    /// overwrite a paint here.
    var settingsDraftPending: () -> Bool = { false }
    var captureShelfBaseline: () -> KiwiCore.ShelfPaintBaseline? = {
        nil
    }
    /// Paints a look with its palette, or a palette alone, live
    /// and into the live profile (`KiwiCore.paintShelf`).
    var onPaintShelf: (ShelfLook?, ColorPalette?) -> Void = { _, _ in }
    var onRestoreShelf: (KiwiCore.ShelfPaintBaseline) -> Void = { _ in }

    var hasLookChanges: Bool { looksBaseline != nil }

    /// The palette `look` names, if it is still saved.
    func palette(of look: ShelfLook) -> ColorPalette? {
        KiwiCore.palette(of: look, in: shelfPalettes())
    }

    /// Applies `look` — its shape and its palette.
    func pickLook(_ look: ShelfLook) {
        paint(look, palette(of: look))
    }

    /// Repaints the colours alone, keeping the shape.
    func pickPalette(_ palette: ColorPalette) {
        paint(nil, palette)
    }

    /// Puts back what the step's first paint replaced.
    func revertLooks() {
        guard let baseline = looksBaseline, !settingsDraftPending()
        else { return }
        onRestoreShelf(baseline)
        looksBaseline = nil
        looksRevision += 1
    }

    func refreshLooks() {
        looksRevision += 1
    }

    /// A pick that would change nothing writes nothing, so
    /// Revert stays greyed until something changed.
    private func paint(_ look: ShelfLook?, _ palette: ColorPalette?) {
        guard !settingsDraftPending() else { return }
        let live = tilingSettings()
        var painted = live
        if let look {
            look.apply(to: &painted, palette: palette)
        } else {
            palette?.apply(to: &painted)
        }
        guard painted != live else { return }
        if looksBaseline == nil {
            looksBaseline = captureShelfBaseline()
        }
        onPaintShelf(look, palette)
        looksRevision += 1
    }

    /// Advances to the next step in `plannedSteps`.
    func advance() {
        guard let index = progressIndex,
            index + 1 < plannedSteps.count
        else { return }
        step = plannedSteps[index + 1]
    }

    func continueAfterAccessibility() {
        advance()
    }

    /// The looks step is always next (#1720).
    func continueAfterSpaces() {
        advance()
    }

    func continueAfterLooks() {
        advance()
    }

    func continueAfterKeys() {
        advance()
    }

    /// Commits `openAtLogin` and runs the given exit action (#342).
    func commitLoginItemThen(_ exit: () -> Void) {
        onSetLoginItem(openAtLogin)
        exit()
    }
}
