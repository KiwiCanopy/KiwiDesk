import KiwiDeskCore
import SwiftUI

/// One seeded space, as the tour's spaces step draws it.
struct OnboardingSpaceCard: Identifiable, Equatable {
    let id: String
    let mode: LayoutMode
    /// The screen it sits on, named as the Monitors area names
    /// it — never in inches, which EDID lies about.
    let screen: String
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

    /// Registers/unregisters the login item to match `openAtLogin`.
    /// Wired to `LoginItemManager`; a no-op stub keeps the model
    /// testable without touching `SMAppService`.
    var onSetLoginItem: (Bool) -> Void = { _ in }
    var onOpenSettings: () -> Void = {}
    /// Opens System Settings › Desktop & Dock (#8).
    var onOpenSpaceSettings: () -> Void = {}
    var onFinish: () -> Void = {}
    /// Opens the shortcuts reference without leaving onboarding.
    var onShowShortcuts: () -> Void = {}
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
    /// Connected screens, named as the Monitors area names them.
    var screenNames: () -> [String] = { [] }
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

    // MARK: - Grant

    /// The tour's first screen, and the only one that carries the
    /// wordmark: the wordmark is the app introducing itself, which
    /// happens once. It is a mark-plus-name-plus-tagline lockup,
    /// so the kiwi mark is already inside it and adding a separate
    /// one would put both on a single surface.
    var grant: some View {
        VStack(spacing: 14) {
            wordmark
            Text(
                model.isTrusted
                    ? L(
                        "onboarding.grant.done.title",
                        "Your windows are arranged"
                    )
                    : L(
                        "onboarding.grant.title",
                        "KiwiDesk needs Accessibility"
                    )
            )
            .font(.title.bold())
            .multilineTextAlignment(.center)
            Text(model.isTrusted ? grantedBody : grantBody)
                .multilineTextAlignment(.leading)
                .foregroundStyle(.secondary)
            Spacer()
            if model.isTrusted {
                Button(L("onboarding.continue", "Continue")) {
                    model.continueAfterAccessibility()
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
            } else {
                Button(
                    L(
                        "common.open_system_settings",
                        "Open System Settings"
                    )
                ) {
                    model.onOpenSettings()
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
            }
            waitingLine
            trustLine
        }
    }

    private var wordmark: some View {
        Group {
            if let image = brandWordmark {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    // Sized by WIDTH: a lockup has no point size,
                    // and 180 pt in the 456 pt content column
                    // reads as a logo rather than as a splash.
                    .frame(width: 180)
            } else {
                Image(systemName: "rectangle.3.group")
                    .font(.system(size: 40))
            }
        }
        .accessibilityLabel(L("brand.menu_bar_icon.a11y", "KiwiDesk"))
    }

    @Environment(\.colorScheme) private var colorScheme

    private var brandWordmark: NSImage? {
        colorScheme == .dark
            ? (BrandAssets.wordmarkDark ?? BrandAssets.wordmark)
            : BrandAssets.wordmark
    }

    /// The status glyph, at TEXT height rather than as a 56 pt
    /// hero: the wordmark owns the hero slot on this screen, and
    /// two marks in one slot is one too many. It is never deleted
    /// — lock-versus-check is the only feedback the auto-detect
    /// gives, and it is the channel that separates the two states
    /// now that neither is coloured.
    private var waitingLine: some View {
        Label {
            Text(
                model.isTrusted
                    ? L(
                        "onboarding.grant.granted",
                        "Permission granted"
                    )
                    : L(
                        "onboarding.grant.waiting",
                        "Waiting for permission…"
                    )
            )
        } icon: {
            Image(
                systemName: model.isTrusted
                    ? "checkmark.circle.fill"
                    : "lock.shield"
            )
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .animation(.default, value: model.isTrusted)
    }

    /// SIP and keylogging are the two objections a macOS user
    /// actually has to an Accessibility prompt, so this is the
    /// line that earns the grant. It survived the welcome step's
    /// deletion as a caption rather than a paragraph.
    private var trustLine: some View {
        Text(
            L(
                "onboarding.grant.trust",
                "KiwiDesk never reads your keystrokes, and never "
                    + "asks you to disable System Integrity "
                    + "Protection."
            )
        )
        .font(.caption)
        .multilineTextAlignment(.center)
        .foregroundStyle(.secondary)
    }

    private var grantBody: String {
        L(
            "onboarding.grant.body",
            """
            1. Click “Open System Settings” below.
            2. Find KiwiDesk in the list and turn it on.
            3. Come back here — we detect it automatically.
            """
        )
    }

    /// The moment the grant lands, `startManaging()` arranges
    /// every window behind this one. That is the demonstration —
    /// on the user's own windows, at the moment it means
    /// something — and until #678 Phase 4 pass 11 the tour said
    /// nothing about it and answered with "Permission granted!".
    ///
    /// The second sentence answers "why is this window special"
    /// outright, once. Said once, the exception stops reading as
    /// an inconsistency and starts reading as a rule.
    private var grantedBody: String {
        L(
            "onboarding.grant.done.body",
            """
            Take a look behind this window — everything that was \
            open has been arranged.

            Setup windows like this one are left alone, because \
            they go away.
            """
        )
    }
}
