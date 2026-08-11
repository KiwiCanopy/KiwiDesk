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
    /// Three of these are conditional, which is why **no step
    /// draws a counter**: any "step 3 of 5" is a lie on some
    /// machine.
    enum Step: Equatable, CaseIterable {
        case grant
        case spaces
        case keys
        case separateSpaces
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
            case .keys, .separateSpaces, .done: true
            }
        }
    }

    /// Reaching a closing beat is what counts, not leaving one:
    /// `shouldResume` puts a returning user straight onto `.keys`
    /// (#331), and closing there must still mark discovery shown
    /// or the tour re-pitches on the next launch.
    var step: Step = .grant {
        didSet {
            if step.isClosingBeat { reachedEnd = true }
        }
    }
    var isTrusted = false
    /// The closing card's "open at login" checkbox (#342).
    /// Pre-checked: the app's off-state after a reboot is a desktop
    /// of unmanaged windows, not a neutral absence, so the good
    /// default is on — one uncheck (here or in Settings) opts out.
    var openAtLogin = true

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
    /// Opens System Settings › Desktop & Dock (#8).
    var onOpenSpaceSettings: () -> Void = {}
    var onFinish: () -> Void = {}
    /// Closes onboarding and opens the dashboard (#331).
    var onExploreSettings: () -> Void = {}
    /// Whether the one-time keys step should be shown now (false
    /// once its persisted flag is set). Gated on that flag, NEVER
    /// AX trust, so a later TCC reset never re-pitches (#331).
    var wantsDiscovery: () -> Bool = { false }
    /// Live count of connected displays, so the Spaces
    /// recommendation fires only in the multi-display state that
    /// can actually suffer ambiguous Desktop→profile bindings (#8).
    var displayCount: () -> Int = { 1 }
    /// The seeded spaces, in order, each with its layout and the
    /// screen it landed on.
    var starterSpaces: () -> [OnboardingSpaceCard] = { [] }
    /// The live tuning the schematics draw, so the picture on day
    /// one is the picture Settings shows.
    var tilingSettings: () -> TilingSettings = { TilingSettings() }
    /// The chord families the keys step teaches, read from the
    /// live layer.
    var keyFamilies: () -> [OnboardingKeyFamily] = { [] }

    /// The grant landed, so tiling just arranged every window
    /// behind this one. The step says so rather than announcing
    /// a permission — see `OnboardingView.grant`.
    func continueAfterAccessibility() {
        step = .spaces
    }

    func continueAfterSpaces() {
        if wantsDiscovery() {
            step = .keys
        } else {
            continueAfterKeys()
        }
    }

    /// Shared display Spaces match KiwiDesk's one-active-profile
    /// model. Separate Spaces remain usable for basic tiling, so
    /// this is a recommendation the user may skip — and it comes
    /// LAST of the substantive steps (#678 Phase 4 pass 11):
    /// straight after the grant it made a macOS setting requiring
    /// a logout the second thing KiwiDesk ever said.
    func continueAfterKeys() {
        if DisplaySpacesSetting.recommendsSharedSpaces(
            displayCount: displayCount()
        ) {
            step = .separateSpaces
        } else {
            step = .done
        }
    }

    func continueAfterSeparateSpaces() {
        step = .done
    }

    /// Applies the closing card's "open at login" choice, then runs
    /// the chosen exit. Both exit buttons funnel through here so
    /// the checkbox is honored whichever the user picks (#342).
    func commitLoginItemThen(_ exit: () -> Void) {
        onSetLoginItem(openAtLogin)
        exit()
    }
}

/// The first-launch tour: permission, the spaces it chose, the
/// keys it bound, and the way out.
struct OnboardingView: View {
    @Bindable var model: OnboardingModel
    @EnvironmentObject private var localization: LocalizationManager
    /// Read here rather than in the grant extension: `@Environment`
    /// is a stored property and an extension cannot hold one.
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 20) {
            switch model.step {
            case .grant:
                grant
            case .spaces:
                spaces
            case .keys:
                keys
            case .separateSpaces:
                separateSpaces
            case .done:
                done
            }
        }
        .padding(32)
        // One frame for every step, since the window is sized from
        // `fittingSize` once at creation and never resized on a
        // step change — a per-step frame would clip whichever step
        // is larger than the one that opened.
        .frame(width: 520, height: 430)
    }
}
