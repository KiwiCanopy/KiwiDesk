import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Track shortcut families' offer (#1440): withheld behind
/// a drawer below the Desktop one until the Track layout is in
/// play — a Track space in the config, or a Track verb bound —
/// then opened on arrival. The Desktop offer's shape
/// (`ShortcutsDesktopOfferTests`), one mount.
@Suite("Track shortcuts offer")
struct ShortcutsTrackOfferTests {
    private func reason(
        spaces: [SpaceID: LayoutMode] = [:],
        bindings: [KeyBinding] = [],
        for key: SettingKey = .shortcuts(.moveWindowToTrack)
    ) -> ShortcutsGates.InertReason? {
        var config = GuiConfig()
        config.spaces = Array(spaces.keys)
        config.spaceModes = spaces
        config.layers = [
            KeyLayer(name: KeyLayer.defaultName, bindings: bindings)
        ]
        return ShortcutsGates(config: config).inertReason(for: key)
    }

    private func binding(_ combo: String, _ lua: String) -> KeyBinding {
        KeyBinding(combo: combo, lua: lua, kind: .navigation)
    }

    private let movePrev = "KiwiDesk.move_to_track(\"prev\")"
    private let moveNext = "KiwiDesk.move_to_track(\"next\")"
    private let swapNext = "track.swap(\"next\")"

    /// The offer's boundary: the seed binds no Track verb and a
    /// fresh install has no Track space, so both families answer
    /// "withheld" until either arm holds.
    @Test("a Track space or a bound Track verb opens the offer")
    func trackBoundary() {
        for key: SettingKey in [
            .shortcuts(.moveWindowToTrack), .shortcuts(.swapWithTrack),
        ] {
            #expect(reason(for: key) == .trackUnused)
            // A Track space, whatever else the config holds.
            #expect(
                reason(spaces: ["1": .bsp, "2": .track], for: key)
                    == nil
            )
            #expect(
                reason(spaces: ["1": .bsp], for: key) == .trackUnused
            )
            // Either family's verb, recorded.
            #expect(
                reason(
                    bindings: [binding("ctrl+alt+h", movePrev)],
                    for: key
                ) == nil
            )
            #expect(
                reason(
                    bindings: [binding("ctrl+alt+l", swapNext)],
                    for: key
                ) == nil
            )
            // A Space verb beside them in the same group is not
            // a Track verb.
            #expect(
                reason(
                    bindings: [
                        binding("ctrl+alt+1", "KiwiDesk.focus_space('1')")
                    ],
                    for: key
                ) == .trackUnused
            )
            // An UNRECORDED row is not a binding.
            #expect(
                reason(
                    bindings: [binding("", swapNext)],
                    for: key
                ) == .trackUnused
            )
        }
    }

    /// The offer is the area's: a verb bound in any layer counts.
    @Test("a binding in any layer opens the offer")
    func trackBindingCountsAcrossLayers() {
        var config = GuiConfig()
        config.layers = [
            KeyLayer(name: KeyLayer.defaultName),
            KeyLayer(
                name: "media",
                bindings: [binding("ctrl+alt+j", moveNext)]
            ),
        ]
        #expect(ShortcutsGates(config: config).trackInUse)
    }

    /// The surfacing branches, needled through their bodies the
    /// way the Desktop offer's are — nothing else can see an
    /// `if` inside a `body`.
    @Test("the Track offer draws its branches, once, below Desktop")
    func trackOfferBranchesAreDrawn() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Keybindings/"
            )
        func squashed(_ name: String) throws -> String {
            SourceScan.stripComments(
                try String(
                    contentsOf: root.appendingPathComponent(name),
                    encoding: .utf8
                )
            )
            .split(whereSeparator: \.isWhitespace)
            .joined()
        }
        let source = try squashed("TrackShortcutsOffer.swift")
        // The verdict is the resolver's, never re-derived here.
        #expect(
            source.contains(
                "ShortcutsGates(config:model.config).trackInUse"
            )
        )
        // ONE container in both states, seeded open once in
        // play, never forced shut. No `hasRows` arm: the rows
        // are static, so the Desktop offer's empty case has no
        // counterpart here.
        #expect(
            source.contains(
                "SettingsDisclosure(drawer,isExpanded:$expanded,"
                    + "scrollHoisted:true){families}"
            )
        )
        #expect(source.occurrences(of: "SettingsDisclosure(") == 1)
        #expect(
            source.contains(".onAppear{ifbound{expanded=true}}")
        )
        let mark = source.range(of: "varbody:someView")
        var cursor =
            mark.map {
                source.distance(
                    from: source.startIndex,
                    to: $0.upperBound
                )
            } ?? 0
        let body =
            SourceScan.balanced(
                Array(source),
                from: &cursor,
                open: "{",
                close: "}"
            ) ?? ""
        #expect(!body.isEmpty)
        #expect(!body.contains("else"))
        // …and `bound` reaches the body ONLY as the seed: a bare
        // `if bound { … }` around the container hides the door
        // when unbound with every count above intact
        // (guard-prover, 2026-09-14).
        #expect(body.occurrences(of: "bound") == 1)
        #expect(body.occurrences(of: "families") == 1)
        // `families` WALKS the keys, headings suppressed under
        // the drawer's own title.
        #expect(
            source.contains(
                "ForEach(keys,id:\\.id){keyin"
                    + "KeybindingFamilyRows(model:model,"
                    + "bindings:$bindings,key:key,"
                    + "expander:expander,showsHeading:false)"
            )
        )
        // The `?` rides the accessory slot and is the file's one.
        #expect(source.contains("explanation:helpText,"))
        #expect(source.contains("subject:drawer.control.text"))
        #expect(source.occurrences(of: "HelpButton(") == 1)

        // ONE mount, in Move windows, with its own list and door,
        // BELOW the Desktop offer (owner ruling 2026-09-14).
        let groups = try squashed("KeybindingGroups.swift")
        #expect(groups.occurrences(of: "TrackShortcutsOffer(") == 1)
        let mount = groups.range(
            of: "keys:ShortcutsRowOrder.moveWindowsTrackFamilies,"
                + "drawer:SettingsCatalog.shortcuts.moveWindowsTracks"
        )
        #expect(mount != nil)
        let desktopMount = groups.range(
            of: "keys:ShortcutsRowOrder.moveWindowsDesktopFamilies,"
        )
        #expect(desktopMount != nil)
        if let mount, let desktopMount {
            #expect(desktopMount.lowerBound < mount.lowerBound)
        }
    }
}
