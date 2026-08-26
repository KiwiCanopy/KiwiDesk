import KiwiDeskCore
import SwiftUI

/// One seeded space, as the tour's spaces step draws it.
struct OnboardingSpaceCard: Identifiable, Equatable {
    let id: String
    let mode: LayoutMode
    /// The screen it sits on, named as the Monitors area names
    /// it — never in inches, which EDID lies about.
    ///
    /// `nil` when the space is on no connected display, which is
    /// reachable on a replay with a monitor unplugged. It used to
    /// fall back to "Main screen", asserting the one thing the
    /// code had just failed to determine (localization audit,
    /// 2026-08-11).
    let screen: String?
}

/// View state for the first-launch tour.
@MainActor
@Observable
final class OnboardingModel {
    /// No `.welcome`: its body explained the permission that the
    /// grant step then explained again, so it removed no decision
    /// and cost a click — the same tax turn 15 cut the detection
    /// screen for (#678 Phase 4 pass 11).
    ///
    /// The route still varies — a trusted replay opens past
    /// `.grant` (`OnboardingEntry.replayStep`) — which is why no
    /// step draws a FIXED counter: any "step 3 of 4" is a lie at
    /// some door. `plannedSteps` is the answer that is true on
    /// every machine — see its doc comment for what changed and
    /// what did not (#828). (The tour's one machine-conditional
    /// step, the separate-Spaces recommendation, retired with
    /// #888: bindings are well-defined under the macOS default
    /// now, so there is nothing to recommend.)
    enum Step: Equatable, CaseIterable {
        case grant
        case spaces
        case keys
        case done

        /// Whether reaching this step means the tour has said
        /// what it came to say.
        ///
        /// This is the ONE place the closing beats are
        /// enumerated, and it is a definition rather than a
        /// duplicated condition — the close seam asks
        /// `reachedEnd`, never a list of cases of its own.
        var isClosingBeat: Bool {
            switch self {
            case .grant, .spaces: false
            case .keys, .done: true
            }
        }
    }

    /// Reaching a closing beat is what counts, not leaving one:
    /// `shouldResume` puts a returning user straight onto `.keys`
    /// (#331), and closing there must still mark discovery shown
    /// or the tour re-pitches on the next launch.
    /// `private(set)`, and the whole flow is why (#828, review):
    /// a presentation's plan is resolved once from the step it
    /// opens on, so a door that assigns `step` directly gets a
    /// tour walking one itinerary while the row draws another.
    /// Every entry goes through `beginPresentation(at:)` and
    /// every advance through `advance()`.
    private(set) var step: Step = .grant {
        didSet {
            if step.isClosingBeat { reachedEnd = true }
        }
    }
    var isTrusted = false
    /// How far the boot has got (#802). The granted screen tells
    /// the user their windows ARE arranged, which is false while
    /// the scan is still walking apps — on a heavy session that
    /// was ~10 s of a screen claiming a finished job. So the claim
    /// waits for `.ready` and the screen narrates the count until
    /// then; seeded and kept current by `AppDelegate`.
    var bootPhase: BootPhase = .ready
    /// The closing card's "open at login" checkbox (#342).
    /// Pre-checked: the app's off-state after a reboot is a desktop
    /// of unmanaged windows, not a neutral absence, so the good
    /// default is on — one uncheck (here or in Settings) opts out.
    var openAtLogin = true

    /// The steps THIS presentation will show, in order — the
    /// progress row's whole content (#828).
    ///
    /// Resolved once, at `beginPresentation(at:)`, and never
    /// recomputed while the tour is up. Two reasons, and the
    /// second is the one that decides it:
    ///
    /// - a length that moves under the reader is the counter
    ///   pass 11 banned, in motion rather than at rest — unplug a
    ///   display and a recomputing row would re-number every pip
    ///   after the one being read;
    /// - the list must start at the step this presentation OPENED
    ///   on, which is not always `.grant` (`OnboardingEntry`), and
    ///   that is a fact about the door rather than about the
    ///   machine, so nothing later can re-derive it.
    ///
    /// It is also the ITINERARY, not a description of one:
    /// `advance()` walks this list, so a display unplugged
    /// mid-tour changes neither the row nor the route and the
    /// tour shows the screen it promised. The alternative — a
    /// flow re-asking the predicate while the row does not — is
    /// the disagreement that bit this branch twice.
    ///
    /// Empty until the first presentation begins — the model is a
    /// stored property on `AppDelegate` and exists long before any
    /// window fills it. The row draws nothing rather than guessing.
    private(set) var plannedSteps: [Step] = []

    /// Opens the tour at `step` and resolves the row's length for
    /// this presentation.
    ///
    /// One call, so the two cannot disagree: a plan set beside a
    /// separate `step =` assignment is two statements about the
    /// same presentation, and the second one added at a new door
    /// would be the one that is forgotten.
    func beginPresentation(at step: Step) {
        self.step = step
        plannedSteps = OnboardingEntry.plannedSteps(from: step)
    }

    /// How far along `plannedSteps` the tour is, zero-based, or
    /// `nil` before a presentation has begun — and, unreachably,
    /// if the current step ever left the plan. Stated as an
    /// Optional rather than forced: a crash in the first window
    /// every user sees is the worse failure.
    var progressIndex: Int? {
        plannedSteps.firstIndex(of: step)
    }

    /// Whether the tour reached its closing beats.
    ///
    /// The close seam keys on THIS, not on a list of terminal
    /// steps. `windowWillClose` used to name the two by case, and
    /// `HomeSurfacingTests` needled the calls inside that `if`
    /// rather than its condition — so renaming or reordering the
    /// terminal steps would have left the suite green and Home's
    /// first-run banner permanently dead.
    private(set) var reachedEnd = false

    /// Consumed by the close seam, so the flag scopes to ONE
    /// presentation of the tour rather than to the model, which
    /// is a stored property on the delegate and outlives every
    /// window it ever fills.
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

    /// One step forward along THIS presentation's plan.
    ///
    /// The plan is the itinerary, not a description of one. Every
    /// `continueAfter*` below is a named call site for it rather
    /// than a decision of its own — which is what makes a
    /// disagreement between the row and the flow unconstructible
    /// instead of test-caught (architecture review, 2026-08-12).
    /// The branch that used to live in `continueAfterKeys` is now
    /// the plan's own membership, resolved once, so a display
    /// unplugged mid-tour can no longer make the flow skip a
    /// screen the row still counts.
    ///
    /// Silent at the end of the plan: the last step's action is
    /// an exit, and a `Continue` that ran off the end would be a
    /// programming error the user should not meet as a crash.
    func advance() {
        guard let index = progressIndex,
            index + 1 < plannedSteps.count
        else { return }
        step = plannedSteps[index + 1]
    }

    /// The grant landed, so tiling just arranged every window
    /// behind this one. The step says so rather than announcing
    /// a permission — see `OnboardingView.grant`.
    func continueAfterAccessibility() {
        advance()
    }

    /// The keys step is ALWAYS next (#828, owner 2026-08-12).
    ///
    /// It used to be gated on a `wantsDiscovery` seam reading the
    /// persisted discovery flag, so a tour whose flag was already
    /// set walked straight from the spaces to the closing card —
    /// the shortcuts screen, the one screen a returning user most
    /// likely reopened the tour for, was the screen they could
    /// never see again. The seam had no other reader and went
    /// with the gate.
    ///
    /// #331's ruling survives intact, because it was never about
    /// this: the flag decides whether an unfinished tour RESUMES
    /// on the keys step at launch (`OnboardingDiscovery`), which
    /// is what must not re-pitch. Being part of a tour the user
    /// opened is a different question, and the answer is yes.
    func continueAfterSpaces() {
        advance()
    }

    func continueAfterKeys() {
        advance()
    }

    /// Applies the closing card's "open at login" choice, then runs
    /// the chosen exit. Both exit buttons funnel through here so
    /// the checkbox is honored whichever the user picks (#342).
    func commitLoginItemThen(_ exit: () -> Void) {
        onSetLoginItem(openAtLogin)
        exit()
    }
}
