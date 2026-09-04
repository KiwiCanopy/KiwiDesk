import AppKit
import Combine
import KiwiDeskCore
import SwiftUI

/// Dashboard view model: editable `GuiConfig` plus live backend state
/// displayed by settings (#36).
@MainActor
final class SettingsModel: ObservableObject {
    /// The visually edited configuration.
    @Published var config: GuiConfig {
        didSet {
            if !suppressDirty { recomputeDirty() }
        }
    }
    /// Raw init.lua when unrepresentable visually or opted into.
    @Published var luaSource = "" {
        didSet {
            if !suppressDirty { recomputeDirty() }
        }
    }
    /// True while foreign Lua forces the raw editor.
    @Published var forcedLuaEditor = false
    /// The log query the Advanced export runs (#1209) — a seam so
    /// a GUI test never spawns `/usr/bin/log`.
    var logExport = LogExport()
    /// The export in progress and its problem, on the model so a
    /// user who navigates away mid-run still meets the outcome.
    @Published var isExportingLog = false
    @Published var logExportProblem: LogExportProblem?
    /// True when init.lua has harmless custom Lua (coexistence banner).
    /// Always false when `forcedLuaEditor` is true.
    @Published var hasCustomLua = false
    /// User toggle to edit init.lua directly.
    @Published var showLuaEditor = false
    /// Live comparison against as-loaded baselines indicating pending edits.
    @Published var isDirty = false
    /// Transient navigation state: reveal request, scroll/flash, tab (#277).
    @Published var nav = SettingsNavigation()
    /// App-wide appearance choice; stored in `AppearancePreference` (#678).
    @Published var appearance: AppearanceChoice = .system
    /// Live auto-start status, refreshed before first paint (#678).
    @Published var autoStart = AutoStartStatus(
        level: .atLogin,
        unavailable: nil,
        requiresApproval: false
    )
    /// False until initial async read lands; controls pending state.
    @Published var autoStartLoaded = false
    /// Write in flight; disables driving auto-start rows.
    @Published var autoStartBusy = false
    /// Last adopted OS auto-start level for live-apply confirmation.
    @Published var autoStartApplied: AutoStartLevel?
    /// Token guarding confirmation fade against rapid changes.
    var autoStartFlashToken = 0
    /// Active navigation destination screen, or nil for Home grid (#678).
    ///
    /// The `didSet` is the one place the input source is
    /// recorded (#991): every navigation path already passes
    /// through this property, and the read is only valid while
    /// the event that caused it is still being dispatched.
    @Published var destination: SettingsDestination? {
        didSet { nav.navigationMovesFocus = SettingsInputSource.movesFocus }
    }
    /// Simple or Power User mode; stored in `SettingsModePreference` (#678).
    @Published var settingsMode: SettingsMode = .simple
    /// True during mode-reveal wash; set by explicit flip only (#760).
    @Published var modeRevealActive = false
    /// Running reveal timeline task superseded by newer flips
    /// (`SettingsModeRevealTests`, #979).
    var modeRevealTask: Task<Void, Never>?
    /// Distinct setting changes in draft, recomputed beside `isDirty`.
    @Published var draftChangeCount = 0
    /// Destructive action behind unsaved-changes dialog (#515).
    @Published var pendingDiscard: PendingDiscard?
    /// Clean baseline state compared against `isDirty`; set by `apply(_:)`.
    var cleanConfig = GuiConfig()
    var cleanLuaSource = ""
    /// Space list as seeded from live/stored state
    /// (`KiwiCore.mergeLiveSpaces`).
    var seedSpaces: [SpaceID] = []

    // `recomputeDirty()` lives in `SettingsModel+Mode.swift` (§2.1).

    /// `UserDefaults` seam for non-config preferences; tests inject a scratch
    /// domain.
    let preferences: UserDefaults

    /// Active saved profile, or nil for a transient state.
    @Published var activeProfile: String?
    /// Built-in Standard resolving when no saved profile covers screens (#53).
    @Published var activeStandard: String?
    /// True when live state diverged from saved profile.
    @Published var profileDirty = false
    /// Dashboard edit target: live config or stored profile (#18, #64).
    @Published var target: EditTarget = .live
    /// Whether monitor placement canvas is editable for current target (#18).
    @Published var placementEditable = true
    @Published var profiles: [String] = []
    /// Rich rows for saved profiles: monitor sets, screen count, matches
    /// (#36).
    @Published var profileSummaries: [ProfileSummary] = []
    /// Un-decodable profiles shown greyed with reveal and delete
    /// (#171, #246, #678).
    @Published var brokenProfiles: [BrokenProfile] = []
    /// Screen counts where multiple profiles claim default flag.
    @Published var duplicateDefaultCounts: [Int] = []
    /// Confirmation text after search flipped mode
    /// (`SettingsModel+Search`, #678).
    @Published var searchModeNotice: String?
    /// Task cancelling previous notice clear on new search flips.
    var searchNoticeTask: Task<Void, Never>?

    /// Profile resolution summary snapshot refreshed by `refreshProfiles`
    /// (#678).
    @Published var profileResolution = ProfileResolution(
        verdict: .none,
        screens: 0
    )
    /// Dismissible warning from profile actions (e.g. monitor overlap).
    @Published var profileWarning: String?

    /// Main screen user Desktops by Mission Control number (#888).
    @Published var mainDesktops: [Int] = []
    /// Active native Space Mission Control number, or nil without SkyLight.
    @Published var currentDesktop: Int?

    /// Bindable user Desktops snapshot (`KiwiCore.bindableDesktops`, #888).
    @Published var bindableDesktops: [Int] = []

    /// Each present Desktop's durable key by its Mission Control
    /// number (#1147) — the join a Profiles row resolves its
    /// binding through, from the same snapshot as `mainDesktops`.
    /// A number absent here names no Desktop right now, which is
    /// what makes a binding on it dormant.
    @Published var desktopKeys: [Int: DesktopKey] = [:]

    /// Every key the topology answers to (#1147) — Core's own
    /// presence verdict as data, so a row builder never
    /// re-derives dormancy per key shape.
    @Published var presentDesktopKeys: Set<DesktopKey> = []

    /// Whether this macOS drives native Desktops (#1145) — read
    /// once from the core (process-constant, so not published);
    /// gates the sticky-reach row's SURFACING (hide, never grey
    /// — `canDriveDesktops`' own ruling). A test flips it to
    /// surface the gated row.
    var canDriveDesktops: Bool

    /// Transient warning for newly introduced keybinding conflicts.
    @Published var keybindingWarning: String?

    /// Injectable live read of one symbolic hotkey's `enabled`
    /// bit (#1105); nil = no plist entry, shipped default
    /// applies. `makeTestModel` injects `{ _ in nil }` so no
    /// suite reads the host's `com.apple.symbolichotkeys`.
    var readSymbolicHotkey: (Int) -> Bool? =
        SystemShortcutEnablement.liveRead

    /// True when macOS Accessibility is missing; drives
    /// `PermissionPausedBanner`.
    @Published var permissionPaused = false
    /// Routes paused banner button to macOS System Settings pane.
    var onResolvePermission: () -> Void = {}
    /// Reveals profile file in Finder (`AppDelegate+Onboarding`, #246).
    var onRevealProfile: (String) -> Void = { _ in }
    /// Routes banner button to voluntary welcome tour replay.
    var onShowTour: () -> Void = {}

    let core: KiwiCore
    /// Recorder live session delta and rollback point (#123).
    var liveKeySession: RecorderLiveSession?
    /// Guards `config.didSet` during reload; written only by `apply(_:)`.
    var suppressDirty = false
    /// Sidecar baseline deciding if save regenerates global files
    /// (`SettingsModel+Profiles`).
    var savedSidecar: GuiConfig?
    /// Base key layers diff baseline for profile shortcuts editing (#55).
    var profileEditingBaseLayers: [KeyLayer]?
    /// Base app rules diff baseline for profile rules editing (#109).
    var profileEditingBaseAppRules: [String: SpaceID]?
    /// Global float rules used to resolve and diff a stored profile.
    var profileEditingBaseFloatRules: [String]?

    /// Injected preferences seam allowing scratch domain in tests.
    init(
        core: KiwiCore,
        preferences: UserDefaults = .standard
    ) {
        self.core = core
        self.config = GuiConfig()
        self.preferences = preferences
        self.canDriveDesktops = core.canDriveDesktops
        // The search filter cannot reach the core, and the fact
        // is process-constant — mirror it once (#1145).
        SettingsSearchIndex.canDriveDesktops =
            core.canDriveDesktops
        self.settingsMode = SettingsModePreference.read(
            from: preferences
        )
        self.appearance = AppearancePreference.read(
            from: preferences
        )
        reload()
    }

    /// Global color-palette library keyed off config directory (#375).
    /// Unapplied settings from last restore, or nil if complete (#606).
    @Published var lastRestoreOutcome: RestoreOutcome?
}
