import KiwiDeskCore
import SwiftUI

/// One seeded space, as the tour's spaces step draws it.
struct OnboardingSpaceCard: Identifiable, Equatable {
    let id: String
    let mode: LayoutMode
    /// The screen name it sits on, or nil if not currently connected.
    let screen: String?
}

/// View state for the first-launch tour.
@MainActor
@Observable
final class OnboardingModel {
    /// Onboarding tour steps (#678, #828, #888).
    enum Step: Equatable, CaseIterable {
        case grant
        case spaces
        case keys
        case done

        /// Whether reaching this step marks tour completion.
        var isClosingBeat: Bool {
            switch self {
            case .grant, .spaces: false
            case .keys, .done: true
            }
        }
    }

    /// Current step, updated via `beginPresentation(at:)` and `advance()`.
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
        plannedSteps = OnboardingEntry.plannedSteps(from: step)
    }

    /// Zero-based index of current step in `plannedSteps`.
    var progressIndex: Int? {
        plannedSteps.firstIndex(of: step)
    }

    /// Whether the tour reached a closing beat.
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
    var onFinish: () -> Void = {}
    /// The seeded spaces, in order, each with its layout and the
    /// screen it landed on.
    var starterSpaces: () -> [OnboardingSpaceCard] = { [] }
    /// The live tuning the schematics draw, so the picture on day
    /// one is the picture Settings shows.
    var tilingSettings: () -> TilingSettings = { TilingSettings() }
    /// The chord families the keys step teaches, read from the
    /// live layer.
    var keyFamilies: () -> [OnboardingKeyFamily] = { [] }

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

    func continueAfterSpaces() {
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
