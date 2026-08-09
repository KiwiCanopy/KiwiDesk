import CoreGraphics
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The diff-row readout's totality net and a behavioural
/// battery (#678 turn 9, Phase 4 shell): every census key that
/// names a model path must NARRATE — a key the readout cannot
/// state would put a change in the count that the panel's list
/// then silently omits, which is exactly the partial-list claim
/// the popover was parked to avoid.
///
/// `@MainActor` because the readout is (`L()` routes through
/// the main-actor locale catalog).
@MainActor
@Suite("Settings value readout")
struct SettingsValueReadoutTests {
    /// Every assertion compares `L()` output to English, so
    /// each test pins the shared manager as its FIRST line —
    /// "System default" resolves the HOST's language
    /// (`MonitorReadoutTests` is the standing idiom).
    private func pinEnglish() {
        LocalizationManager.shared.select("en")
    }

    /// The keys the totality net covers: a model path the walk
    /// can book. Suffix-stripping mirrors
    /// `SettingsDraftDiff.censusBases()`.
    private var modelPathKeys: [SettingKey] {
        SettingKey.allCases.filter {
            $0.id.hasPrefix("settings.")
                || $0.id.hasPrefix("config.")
        }
    }

    /// A key that expands per instance: its id names a slot,
    /// or it is one of the LIST keys whose id carries no
    /// bracket but whose narration is membership rows — those
    /// legitimately return [] on equal configs, so each earns
    /// its place here by a mutation in the battery below.
    private func instanced(_ key: SettingKey) -> Bool {
        if key.id.contains("[") { return true }
        return listKeys.contains(key.id)
    }

    private let listKeys: Set<String> = [
        "config.spaces",
        "config.floatRules",
        "config.ignoreRules",
        "config.mainSpaces",
        "config.layers",
    ]

    @Test("every scalar model-path key narrates on defaults")
    func scalarKeysNarrate() {
        pinEnglish()
        let config = GuiConfig()
        for key in modelPathKeys
        where !instanced(key)
            && !SettingsValueReadout.noReadout.contains(key)
        {
            let rows = SettingsValueReadout.rows(
                for: key,
                old: config,
                new: config
            )
            #expect(
                !rows.isEmpty,
                Comment(rawValue: "\(key.id) narrates nothing")
            )
            for row in rows {
                #expect(
                    !row.label.isEmpty,
                    Comment(rawValue: "\(key.id) has no label")
                )
            }
        }
    }

    @Test("the exemption list stays inside the model-path set")
    func noReadoutIsSubset() {
        let paths = Set(modelPathKeys)
        for key in SettingsValueReadout.noReadout {
            #expect(
                paths.contains(key),
                Comment(
                    rawValue:
                        "\(key.id) is exempt but has no "
                        + "model path to be exempt FROM"
                )
            )
        }
    }

    /// Instanced keys cannot be proven total generically (an
    /// unimplemented arm and a legitimately-empty diff both
    /// return []), so each family is proven on a real
    /// mutation. A new instanced census key joins this battery
    /// in the same change.
    @Test("instanced families narrate their mutations")
    func instancedFamiliesNarrate() {
        pinEnglish()
        let clean = GuiConfig()
        var edited = clean

        edited.settings.gapsOverride[SpaceID("mail")] = Gaps()
        expectRows(.gaps(.perSpaceOverride), clean, edited)

        edited = clean
        edited.spaces = [SpaceID("a")]
        edited.spaceModes[SpaceID("a")] = .monocle
        var base = clean
        base.spaces = [SpaceID("a")]
        expectRows(.spaces(.spaceModes), base, edited)

        edited = base
        edited.settings.spaceIcons[SpaceID("a")] = "star"
        expectRows(.spaces(.spaceIcon), base, edited)

        edited = clean
        edited.appRules["com.apple.mail"] = SpaceID("mail")
        expectRows(.appRules(.appRules), clean, edited)

        edited = clean
        edited.floatRules = ["com.apple.calculator"]
        expectRows(.appRules(.floatRules), clean, edited)

        edited = clean
        edited.settings.placementOverride[SpaceID("a")] =
            .first
        expectRows(
            .behaviour(.placementOverride),
            clean,
            edited
        )

        edited = clean
        edited.profileBindings[2] = "Desk"
        expectRows(
            .profiles(.profileBindings),
            clean,
            edited
        )

        edited = clean
        edited.spaces = [SpaceID("new")]
        expectRows(.spaces(.spaceList), clean, edited)

        edited = clean
        edited.ignoreRules = ["com.apple.finder"]
        expectRows(.appRules(.ignoreRules), clean, edited)

        edited = clean
        edited.mainSpaces = [SpaceID("a")]
        expectRows(.monitors(.mainSpaces), clean, edited)

        edited = clean
        edited.layers[0].bindings = [
            KeyBinding(
                combo: "alt-j",
                lua: "KiwiDesk.focus(\"down\")"
            )
        ]
        expectRows(.shortcuts(.layers), clean, edited)
    }

    @Test("a value pair narrates both sides")
    func valuePairNarrates() {
        pinEnglish()
        let clean = GuiConfig()
        var edited = clean
        edited.settings.gapsGlobal.outer.top = 24
        let rows = SettingsValueReadout.rows(
            for: .gaps(.outerTop),
            old: clean,
            new: edited
        )
        #expect(rows.count == 1)
        #expect(rows.first?.oldValue == "10 pt")
        #expect(rows.first?.newValue == "24 pt")
    }

    @Test("a master row reads mixed when its edges disagree")
    func masterReadsMixed() {
        pinEnglish()
        let clean = GuiConfig()
        var edited = clean
        edited.settings.gapsGlobal.outer.top = 24
        let rows = SettingsValueReadout.rows(
            for: .gaps(.outer),
            old: clean,
            new: edited
        )
        #expect(rows.first?.oldValue == "10 pt")
        #expect(rows.first?.newValue == "mixed")
    }

    @Test("a toggle narrates state words, never true/false")
    func togglesNarrateWords() {
        pinEnglish()
        let clean = GuiConfig()
        for key in modelPathKeys where !instanced(key) {
            for row in SettingsValueReadout.rows(
                for: key,
                old: clean,
                new: clean
            ) {
                for value in [row.oldValue, row.newValue] {
                    #expect(
                        value != "true" && value != "false",
                        Comment(
                            rawValue:
                                "\(key.id) leaks a raw Bool"
                        )
                    )
                }
            }
        }
    }

    /// Every changed setting the attribution books yields at
    /// least one row through the row source — the panel-level
    /// promise: count and list cover the same draft. Proven on
    /// a broad mutation rather than key-by-key, so a key whose
    /// narration filters ITS OWN change to nothing reds here.
    @Test("booked changes always render rows")
    func bookedChangesRenderRows() {
        pinEnglish()
        let clean = GuiConfig()
        var edited = clean
        edited.settings.gapsGlobal.inner.horizontal = 4
        edited.settings.minWindowSize = 350
        edited.settings.borderStyle.enabled.toggle()
        edited.settings.spaceBarStyle.thickness += 4
        edited.spaces = [SpaceID("a"), SpaceID("b")]
        edited.settings.animations.onScrolling.toggle()
        let diff = SettingsDraftDiff.between(
            config: edited,
            cleanConfig: clean
        )
        #expect(diff.unattributed.isEmpty)
        for key in diff.changedSettings {
            let rows = SettingsValueReadout.rows(
                for: key,
                old: clean,
                new: edited
            )
            #expect(
                !rows.isEmpty,
                Comment(
                    rawValue:
                        "\(key.id) was booked but narrates "
                        + "nothing"
                )
            )
        }
    }

    private func expectRows(
        _ key: SettingKey,
        _ old: GuiConfig,
        _ new: GuiConfig,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let rows = SettingsValueReadout.rows(
            for: key,
            old: old,
            new: new
        )
        #expect(
            !rows.isEmpty,
            Comment(
                rawValue: "\(key.id) narrates no rows"
            ),
            sourceLocation: sourceLocation
        )
    }
}
