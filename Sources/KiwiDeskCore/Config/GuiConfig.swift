import Foundation

/// The GUI's editable configuration split across global `gui.json` and
/// active profile JSON (#36, #55).
public struct GuiConfig: Codable, Equatable, Sendable {
    public var format: Int = GuiConfig.currentFormat
    /// Active profile tiling parameters.
    public var settings = TilingSettings()
    /// User-defined Spaces in display order.
    public var spaces: [SpaceID] = []
    /// Layout mode per Space (profile-scoped). SPARSE: `.bsp`
    /// is the omitted default, so read it through `modes(for:)`
    /// rather than spelling that default again at a call site.
    public var spaceModes: [SpaceID: LayoutMode] = [:]

    /// App -> space assignment (`app_rules`).
    public var appRules: [String: SpaceID] = [:]
    /// Space -> monitor fingerprint pin (profile-scoped).
    public var spacePins: [SpaceID: String] = [:]
    /// Spaces following the main display (profile-scoped).
    public var mainSpaces: Set<SpaceID> = []
    /// Explicit fallback space when a profile switch drops spaces (#68).
    public var fallbackSpace: SpaceID?
    /// Windows that never tile (`float_rules`).
    public var floatRules: [String] = []
    /// Apps never managed (`ignore_rules`, #176).
    public var ignoreRules: [String] = []
    /// Desktop -> the profile it selects (#1147). Keyed by the
    /// Desktop's own stamp where it carries one, so a binding
    /// survives a renumber; by its Mission Control number where
    /// it does not (no bridge on this macOS, or a stamp declined).
    /// Stored in `bindings.json`, never `gui.json` (#2324).
    public var profileBindings: [DesktopKey: DesktopBinding] = [:]
    /// The Space each Desktop was last showing (#1230), so a
    /// restart does not re-scatter them.
    ///
    /// **Identity-keyed entries only** — a `.number` key is the
    /// bridge-absent fallback, and a number means nothing without
    /// saying whose numbering it is, so two arrangements collide
    /// on one entry. `virtualSpaces` accepts that in memory
    /// because a wrong answer heals at the next departure; once
    /// persisted it does not, so the encoder drops them
    /// (profiles.md ▸ "Never carry the `.number` fallback's
    /// collision into a PERSISTED map"). Stored in
    /// `machine.json`, never `gui.json` (`machineLocalFields`).
    public var desktopSpaces: [DesktopKey: SpaceID] = [:]
    /// Keybinding modes; first is default mode.
    public var layers: [KeyLayer] = [KeyLayer.defaultLayer]
    /// The scroll gestures' global base (#1656); a profile
    /// diverges through `Profile.scrollGesture`.
    public var scrollGesture: ScrollGestureBase = .defaults
    /// The Space history's global base (#1655); a profile diverges
    /// through `Profile.spaceHistory`.
    public var spaceHistory = SpaceHistoryKind.defaultKind
    /// The layouts the cycle walks (#453); a profile diverges
    /// through `Profile.modeCycle`.
    public var modeCycle = ModeCycle.defaultList
    /// Whether detection floats windows on a guess — a fixed size,
    /// no Dock icon — (#2173); a profile diverges through
    /// `Profile.floatAutomatically`.
    public var floatAutomatically = FloatGuess.enabledByDefault
    /// Apps whose guessed floats tile (`tile_rules`, #2173).
    public var tileRules: [String] = []
    /// The base the default shortcuts sit on (`shortcut_base`,
    /// #2460): app-wide, drafted with `layers` so a Save moves the
    /// rows and the base together.
    public var shortcutBase = ShortcutBase.standard
    /// The settings no profile carries (#1741); nil until adopted.
    /// Stamped at the write (`GuiConfigStore.liveAppWide`), never
    /// drafted: General writes them the moment they change.
    public var appWide: AppWideSettings?
    /// The shared look every profile without its own wears
    /// (#1752); nil until this file has adopted one. Stamped at the
    /// write (`GuiConfigStore.liveLook`), like `appWide`.
    public var look: LookBody?
    /// The default rows this setup was offered (#2324); nil on a
    /// file written before the offer travelled. Merged upward at
    /// the write (`GuiConfigStore.save`), never drafted.
    public var shortcutOffer: ShortcutOffer?

    /// Fields that ride `gui.json` without being settings the
    /// user DRAFTS — the Settings walk, the census guard and the
    /// save pill all skip them, so the reason lives here rather
    /// than three times.
    ///
    /// `format` is file metadata. `desktopSpaces` is runtime
    /// Desktop memory (#1230): it changes every time you swipe a
    /// Desktop, so counting it as a config change would light the
    /// save pill constantly, and it is stamped at the write
    /// (`GuiConfigStore.liveDesktopSpaces`) rather than drafted.
    /// `appWide` (#1741) and the shared `look` (#1752) are
    /// stamped the same way, and `shortcutOffer` (#2324) is the
    /// top-ups' bookkeeping, merged at the write.
    public static let undraftedFields: Set<String> = [
        "format", "desktopSpaces", "appWide", "look", "shortcutOffer",
    ]

    /// Fields `gui.json` never carries: they mean something on
    /// this Mac alone, so they live in `MachineConfig` (#2324),
    /// which `GuiConfigStore` composes in at a load and splits out
    /// at a save. The encoder and decoder below skip them.
    public static let machineLocalFields: Set<String> = [
        "desktopSpaces", "profileBindings",
    ]

    public init() {}

    /// Only the global fields persist in the sidecar — the
    /// profile-scoped ones round-trip through the profile JSON
    /// instead (#36), which is what lets the two files never
    /// drift.
    private enum CodingKeys: String, CodingKey {
        case format
        case spaces
        case appRules = "app_rules"
        case floatRules = "float_rules"
        case ignoreRules = "ignore_rules"
        case layers
        case scrollGesture = "scroll_gesture"
        case spaceHistory = "space_history"
        case modeCycle = "mode_cycle"
        case floatAutomatically = "float_automatically"
        case tileRules = "tile_rules"
        case shortcutBase = "shortcut_base"
        case refusal
        case quit
        case desktop
        case space
        case mode
        case kiwivision
        case hyper
        case look
        case shortcutOffer = "shortcut_offer"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        let decodedFormat =
            try container.decodeIfPresent(
                Int.self,
                forKey: .format
            ) ?? 0
        guard decodedFormat <= Self.currentFormat else {
            throw DecodingError.dataCorruptedError(
                forKey: .format,
                in: container,
                debugDescription:
                    "gui config format \(decodedFormat) is newer "
                    + "than supported \(Self.currentFormat)"
            )
        }
        format = Self.currentFormat
        spaces =
            try container.decodeIfPresent(
                [SpaceID].self,
                forKey: .spaces
            ) ?? []
        appRules =
            try container.decodeIfPresent(
                [String: SpaceID].self,
                forKey: .appRules
            ) ?? [:]
        floatRules =
            try container.decodeIfPresent(
                [String].self,
                forKey: .floatRules
            ) ?? []
        ignoreRules =
            try container.decodeIfPresent(
                [String].self,
                forKey: .ignoreRules
            ) ?? []
        // A hand-edited sidecar can carry duplicate mode names or
        // an icon on the default mode (#31) — normalized here so
        // invalid entries never reach the loader or the GUI.
        layers = KeyLayer.normalized(
            full: try container.decodeIfPresent(
                [KeyLayer].self,
                forKey: .layers
            ) ?? []
        )
        // Additive since #1656: absence is the defaults.
        scrollGesture =
            try container.decodeIfPresent(
                ScrollGestureBase.self,
                forKey: .scrollGesture
            ) ?? .defaults
        // Additive since #1655: absence is the default.
        spaceHistory =
            try container.decodeIfPresent(
                SpaceHistoryKind.self,
                forKey: .spaceHistory
            ) ?? .defaultKind
        // Additive since #453: absence is the default list.
        modeCycle = try ModeCycle.decoded(container, forKey: .modeCycle)
        // Additive since #2173: absence is the defaults.
        floatAutomatically =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .floatAutomatically
            ) ?? FloatGuess.enabledByDefault
        tileRules =
            try container.decodeIfPresent(
                [String].self,
                forKey: .tileRules
            ) ?? []
        // Absence is the seed's own base (#2460).
        shortcutBase =
            try container.decodeIfPresent(
                ShortcutBase.self,
                forKey: .shortcutBase
            ) ?? .standard
        // Additive since #1741: absence is
        // "not adopted yet", which the adoption reads.
        appWide = AppWideSettings(
            refusal: try container.decodeIfPresent(
                AppWideSettings.Refusal.self,
                forKey: .refusal
            ),
            quit: try container.decodeIfPresent(
                AppWideSettings.Quit.self,
                forKey: .quit
            ),
            desktop: try container.decodeIfPresent(
                AppWideSettings.Desktop.self,
                forKey: .desktop
            ),
            space: try container.decodeIfPresent(
                AppWideSettings.Space.self,
                forKey: .space
            ),
            mode: try container.decodeIfPresent(
                AppWideSettings.Mode.self,
                forKey: .mode
            ),
            vision: try container.decodeIfPresent(
                AppWideSettings.Vision.self,
                forKey: .kiwivision
            ),
            hyper: try container.decodeIfPresent(
                AppWideSettings.Hyper.self,
                forKey: .hyper
            )
        )
        // Additive since #1752: absence is "no shared look adopted
        // yet", which the crossing reads.
        look = try container.decodeIfPresent(
            LookBody.self,
            forKey: .look
        )
        // Additive since #2324: absence is "never offered here".
        shortcutOffer = try container.decodeIfPresent(
            ShortcutOffer.self,
            forKey: .shortcutOffer
        )
        dropEmptyNamedSpaces()
    }

    private mutating func dropEmptyNamedSpaces() {
        // ONE definition of the reference sites (removeSpace)
        // rather than a third hand-mirror; only the appRules VALUE
        // filter stays separate.
        removeSpace(SpaceID(""))
        appRules = appRules.filter { !$0.value.raw.isEmpty }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(
            keyedBy: CodingKeys.self
        )
        try container.encode(format, forKey: .format)
        try container.encode(spaces, forKey: .spaces)
        try container.encode(appRules, forKey: .appRules)
        try container.encode(floatRules, forKey: .floatRules)
        try container.encode(ignoreRules, forKey: .ignoreRules)
        try container.encode(layers, forKey: .layers)
        try container.encode(scrollGesture, forKey: .scrollGesture)
        try container.encode(spaceHistory, forKey: .spaceHistory)
        try container.encode(modeCycle, forKey: .modeCycle)
        try container.encode(
            floatAutomatically,
            forKey: .floatAutomatically
        )
        try container.encode(tileRules, forKey: .tileRules)
        try container.encode(
            shortcutBase,
            forKey: .shortcutBase
        )
        if let appWide {
            try container.encode(appWide.refusal, forKey: .refusal)
            try container.encode(appWide.quit, forKey: .quit)
            try container.encode(appWide.desktop, forKey: .desktop)
            try container.encode(appWide.space, forKey: .space)
            try container.encode(appWide.mode, forKey: .mode)
            try container.encode(appWide.vision, forKey: .kiwivision)
            try container.encode(appWide.hyper, forKey: .hyper)
        }
        try container.encodeIfPresent(look, forKey: .look)
        try container.encodeIfPresent(
            shortcutOffer,
            forKey: .shortcutOffer
        )
    }
}
