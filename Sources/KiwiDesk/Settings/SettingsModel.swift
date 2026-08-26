import AppKit
import Combine
import KiwiDeskCore
import SwiftUI

/// The dashboard's view model: the editable `GuiConfig` plus the
/// live backend state the tabs display (active profile, dirty
/// flag, monitors). Tabs mutate `config` and the change is held
/// until one of the footer's profile actions (Update / Save as
/// new) writes it through `KiwiCore` (#36).
@MainActor
final class SettingsModel: ObservableObject {
    /// The visually edited configuration.
    @Published var config: GuiConfig {
        didSet {
            if !suppressDirty { recomputeDirty() }
        }
    }
    /// Raw init.lua shown when the file holds code the visual
    /// editor can't represent, or when the user opts in.
    @Published var luaSource = "" {
        didSet {
            if !suppressDirty { recomputeDirty() }
        }
    }
    /// True while foreign Lua forces the raw editor.
    @Published var forcedLuaEditor = false
    /// True when init.lua has harmless custom Lua (code that
    /// doesn't touch managed vocabulary). Shows the
    /// informational coexistence banner in the visual editor.
    /// Always false when `forcedLuaEditor` is true.
    @Published var hasCustomLua = false
    /// User toggle to edit init.lua directly.
    @Published var showLuaEditor = false
    /// Unsaved GUI edits are pending. A live comparison
    /// against the as-loaded baselines, not a latched flag —
    /// manually undoing an edit clears the footer again.
    @Published var isDirty = false
    /// The window's transient navigation state — the one-shot
    /// reveal request, its two-phase scroll/flash, and the local
    /// surface selection (the Layout mode tab). Behind one
    /// `@Published` so this file stays under the 350-line
    /// ceiling as #277 part 2 grows the set; a value type, so
    /// `$model.nav.layoutModeTab` still projects a `Binding`.
    @Published var nav = SettingsNavigation()
    /// Which appearance the window follows (#678 item 8).
    ///
    /// Read at init through the `preferences` seam and written
    /// back through `setAppearance`, so it never enters the
    /// dirty-tracked config — it is app-wide, not part of a
    /// profile, and the footer's Save has nothing to do with
    /// it. Storage lives in `AppearancePreference`, which
    /// argues why it is not `gui.json`.
    @Published var appearance: AppearanceChoice = .system
    /// The live auto-start status (#678 item 16).
    ///
    /// Held here, not in `LoginItemCard`, because turn 14b draws
    /// two rows from it in two different containers — see
    /// `SettingsModel+AutoStart` for why that forces the lift and
    /// what it buys. The default is a cheap literal, never a
    /// probe: `refreshAutoStart()` replaces it with the live read
    /// before the first paint the user reads.
    @Published var autoStart = AutoStartStatus(
        level: .atLogin,
        unavailable: nil,
        requiresApproval: false
    )
    /// False until the first async read lands; both rows stay
    /// pending until then.
    @Published var autoStartLoaded = false
    /// A write is in flight, so neither row may be driven.
    @Published var autoStartBusy = false
    /// The level the OS last adopted, shown as the transient
    /// live-apply confirmation (there is no Save to press).
    @Published var autoStartApplied: AutoStartLevel?
    /// Guards the confirmation's fade so a newer change
    /// cancels an older timer instead of clearing the latest
    /// confirmation early.
    var autoStartFlashToken = 0
    /// Which area screen is pushed — nil is Home, the card grid
    /// that replaced the sidebar (#678 turn 9).
    ///
    /// Held here rather than as `@State` in `SettingsView`
    /// because the view is re-keyed on a GUI language change
    /// (`LocaleScopedRoot`), and `@State` does not survive that —
    /// switching language silently threw the user back to the
    /// entry screen mid-task. The model outlives the rebuild, so
    /// the selection does too.
    ///
    /// Home is the *entry* point for a first-run and a returning
    /// user alike (turn 9 supersedes §5.8's Profiles ruling —
    /// the grid IS the overview that made Profiles the landing):
    /// `SettingsWindowController.show()` resets this each time
    /// the window is opened.
    @Published var destination: SettingsDestination?
    /// The Simple/Power User pick (#678 turn 9). Read at init
    /// through the `preferences` seam and written back through
    /// `setSettingsMode`, so it never enters the dirty-tracked
    /// config — same shape and reasoning as `appearance`.
    @Published var settingsMode: SettingsMode = .simple
    /// True while the mode-reveal wash shows (#760): set by
    /// `flipSettingsMode` BEFORE the mode publish, so surfaces
    /// the flip inserts mount already washed, and cleared by the
    /// timeline it starts. Only the EXPLICIT segment flip
    /// activates it — `ensureModeAdmits`' implicit promotion
    /// goes through `setSettingsMode` and stays silent, because
    /// search owns that landing's choreography (ui-designer,
    /// 2026-08-09).
    @Published var modeRevealActive = false
    /// Cancels a running reveal timeline when a newer flip
    /// supersedes it, so a rapid Simple→Power-User→Simple→…
    /// cannot clear the latest wash early.
    ///
    /// Production must not read this as state, and a test
    /// awaiting it (`SettingsModeRevealTests`, #979) must read
    /// it straight after a flip that reveals: it is not an
    /// in-flight predicate — never cleared when the timeline
    /// finishes, and left in place by a flip that does not
    /// reveal — so anywhere else it is a finished predecessor,
    /// and awaiting it asserts nothing.
    var modeRevealTask: Task<Void, Never>?
    /// Distinct settings the draft changes — the header's
    /// "N unsaved changes" count, recomputed beside `isDirty`
    /// from the same baselines so the two cannot disagree.
    @Published var draftChangeCount = 0
    /// A destructive action parked behind the unsaved-changes
    /// dialog (#515). Written only by `discardingEdits` and the
    /// two `*PendingDiscard` verbs in `SettingsModel+Discard`.
    @Published var pendingDiscard: PendingDiscard?
    /// The state as last loaded/saved — what `isDirty`
    /// compares against. Set only by `apply(_:)` (every clean
    /// transition funnels through `reload()`).
    var cleanConfig = GuiConfig()
    var cleanLuaSource = ""
    /// The space list as last seeded from live/stored state.
    /// `persist` diffs the edited list against it so a save can
    /// tell a user deletion (in seed, removed from the model)
    /// from model staleness (a space that appeared live while
    /// the dashboard sat open) — see `KiwiCore.mergeLiveSpaces`.
    var seedSpaces: [SpaceID] = []

    // `recomputeDirty()` lives in `SettingsModel+Mode.swift`
    // with the rest of the draft-state derivations (§2.1
    // headroom — this file sits near the ceiling).

    /// The ONE `UserDefaults` seam for everything this model
    /// persists outside the config — the mode pick, the
    /// first-run banner's flags, the appearance choice — so
    /// tests write a scratch domain instead of the developer's
    /// real defaults (tests.md: process-global state). One
    /// domain, not one per consumer: the split carried no
    /// information and grew the init a parameter per consumer
    /// (architect re-review 2026-08-04, which also caught the
    /// appearance read bypassing the split seams entirely).
    let preferences: UserDefaults

    /// Active saved profile, or nil for a transient state.
    @Published var activeProfile: String?
    /// The built-in Standard currently resolving (no saved
    /// profile covers the live screen count), if any (#53).
    @Published var activeStandard: String?
    /// The live state diverged from the saved profile (e.g.
    /// after a monitor change) — the update prompt.
    @Published var profileDirty = false
    /// The dashboard's edit target (#64/#18): the live config,
    /// or a stored profile edited via the banner dropdown —
    /// seeded from its JSON, never switching the running
    /// layout. Written only by `selectEditTarget` and the
    /// reload fallback; every mode-dependent field derives
    /// from it through the single `reload()`.
    @Published var target: EditTarget = .live
    /// Whether the Canvas (monitor placement) is editable for the
    /// current target: always true live; for a stored profile
    /// only when its monitor set is the one connected now (else
    /// there is no live geometry to render — #18).
    @Published var placementEditable = true
    @Published var profiles: [String] = []
    /// Rich rows for the saved-profiles list (#36): monitor
    /// sets, screen count, default flag, live match.
    @Published var profileSummaries: [ProfileSummary] = []
    /// Profiles whose JSON won't decode — shown greyed with a
    /// Reveal and a Delete, never hidden (#246, #171). No summary:
    /// the file can't be read to build one, which is why the cause
    /// rides along instead (#678 Phase 4 pass 9).
    @Published var brokenProfiles: [BrokenProfile] = []
    /// Screen counts where several profiles claim the default
    /// flag (hand-edited files) — warning badge.
    @Published var duplicateDefaultCounts: [Int] = []
    /// The one-line confirmation after a search pick flipped the
    /// mode (#678 4c) — set and cleared only by
    /// `noteSearchModeSwitch` (`SettingsModel+Search`).
    @Published var searchModeNotice: String?
    /// The notice's self-clear, held so a second flip supersedes
    /// the first instead of racing it.
    var searchNoticeTask: Task<Void, Never>?

    /// What loads right now, by which rule, and over how many
    /// screens (#678 turn 13a) — for the "Which profile loads"
    /// card.
    ///
    /// Snapshotted rather than asked per render: the query scans
    /// the profile directory and decodes every profile, so a
    /// computed property read from `body` would do that on every
    /// SwiftUI pass — and log a line per broken profile each
    /// time. Refreshed by `refreshProfiles`, which already pays
    /// for that scan once.
    ///
    /// The COUNT rides with the verdict rather than being read
    /// live beside it. The card renders both in one sentence, so
    /// two sources would let it say "2 screens → Desk (these
    /// exact monitors)" about a profile that matched the
    /// one-screen set — a sentence assembled from two moments.
    @Published var profileResolution = ProfileResolution(
        verdict: .none,
        screens: 0
    )
    /// A dismissible warning from the last profile action
    /// (overlapping monitor sets, save failures).
    @Published var profileWarning: String?

    /// Snapshotted (not computed per render) so the profile
    /// JSON isn't re-read on every SwiftUI body pass and views
    /// re-render when the drift actually changes. Type and
    /// refresh logic live in SettingsModel+LayoutDrift.swift;
    /// write only through `refreshLayoutDrift()` there.
    @Published var layoutDrift: LayoutDrift?

    /// The MAIN screen's user Desktops, by Mission Control
    /// number (#888) — the Desktops a binding can fire on, which
    /// is what the bindings card offers. Global numbers, possibly
    /// non-contiguous; never positions.
    @Published var mainDesktops: [Int] = []
    /// Mission Control number of the active native Space, for the
    /// "current" badge; nil without SkyLight.
    @Published var currentDesktop: Int?

    /// The Desktops a keybinding may target — every user
    /// Desktop, or none where this macOS has no Desktop bridge
    /// (`KiwiCore.bindableDesktops` joins the two facts).
    ///
    /// A stored snapshot rather than a read per render, for the
    /// two reasons the properties above are: the read scans the
    /// window server's whole space model, and the capability
    /// half caches a process-wide answer the first time anything
    /// asks — a `body` that asked would pin that answer to
    /// whichever render happened first.
    ///
    /// The WIDER list of the two Desktop reads: `mainDesktops`
    /// is what a profile binding can fire on (#888), this is
    /// what a verb can reach.
    @Published var bindableDesktops: [Int] = []

    /// A dismissible in-app warning shown when a keybinding
    /// conflict was just introduced — nil hides the banner. Set
    /// by `noteRecordedCombo` (recording a conflicting shortcut)
    /// and by `adoptIntoGui`/`save`'s raw-Lua path (a batch check
    /// of the resulting config); both also clear it once no
    /// conflict remains. The persistent per-row ⚠️ and its
    /// tooltip are unaffected and always reflect live state.
    @Published var keybindingWarning: String?

    /// True while macOS Accessibility permission is missing, so
    /// window management is fully paused and every tiling control
    /// below is silently inert. Drives the dashboard-wide
    /// `PermissionPausedBanner`. Pushed from `AppDelegate` (the
    /// permission owner) — the Settings layer never reads AX
    /// state directly. Not dismissible: it tracks a persistent
    /// fact, unlike the transient `keybindingWarning`.
    @Published var permissionPaused = false
    /// Routes the paused banner's "Open System Settings" button
    /// to the macOS pane (wired by the app).
    var onResolvePermission: () -> Void = {}
    /// Shows a profile's file in the Finder — the broken-profile
    /// row's one action besides Delete (#246). The SAME closure
    /// the Config Issues panel gets, wired once in `AppDelegate`
    /// rather than a second `fileURL` + `NSWorkspace` body for
    /// one behaviour; `AppDelegate+Onboarding` holds it.
    var onRevealProfile: (String) -> Void = { _ in }
    /// Routes the 14c banner's "Show me around" to the welcome
    /// tour's voluntary replay (wired by the app) — the tour's
    /// first willing caller; the other three are involuntary.
    var onShowTour: () -> Void = {}

    let core: KiwiCore
    /// Recorder-only runtime delta + disk-independent rollback
    /// point (#123). nil outside a live-apply edit session.
    var liveKeySession: RecorderLiveSession?
    /// Guards the `config.didSet` dirty flag during reload
    /// cycles; its only writer is `apply(_:)` in
    /// `SettingsModel+EditTarget.swift`.
    var suppressDirty = false
    /// The sidecar as last loaded — the baseline that decides
    /// whether a save must also regenerate the global files
    /// (see `SettingsModel+Profiles`).
    var savedSidecar: GuiConfig?
    /// The base gui.json modes while editing a stored profile
    /// — the diff baseline for the Shortcuts tab's override
    /// mode (#55 phase 7). nil during live editing. Updated
    /// only inside the reload cycle, which republishes
    /// `config`, so views recompute together.
    var profileEditingBaseLayers: [KeyLayer]?
    /// The base gui.json app→space rules while editing a
    /// stored profile — the App Rules tab's override-mode
    /// baseline (#109), same lifecycle as
    /// `profileEditingBaseLayers`. nil during live editing.
    var profileEditingBaseAppRules: [String: SpaceID]?
    /// Global float rules used to resolve and diff a stored profile.
    var profileEditingBaseFloatRules: [String]?

    /// The preferences seam defaults live and is injected by
    /// tests — a bare default read inside the class would hand
    /// a test-constructed model the runner's real domain
    /// (tests.md: process-global state).
    init(
        core: KiwiCore,
        preferences: UserDefaults = .standard
    ) {
        self.core = core
        self.config = GuiConfig()
        self.preferences = preferences
        self.settingsMode = SettingsModePreference.read(
            from: preferences
        )
        self.appearance = AppearancePreference.read(
            from: preferences
        )
        reload()
    }

    /// The global color-palette library (#375). Stateless and
    /// file-backed, keyed off the config directory — built once
    /// since the directory never changes for a session. Apply is
    /// in `SettingsModel+Palette`.
    /// What the last restore could not take, nil when it took
    /// everything (#606).
    @Published var lastRestoreOutcome: RestoreOutcome?
}
