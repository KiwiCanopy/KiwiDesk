import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The static index's membership and shape (#678 turn 11, spec
/// 11a): one row per GUI-surfaced census setting, the
/// catalog-only anchor rows derived rather than listed, and the
/// match path clean of everything enrichment is allowed to
/// touch. English pinned per body (#90 convention).
@Suite("Settings search index", .serialized)
@MainActor
struct SettingsSearchIndexTests {
    private func pinEnglish() {
        LocalizationManager.shared.select("en")
    }

    private func reset() {
        LocalizationManager.shared.select(nil)
    }

    /// Totality, both directions: every census key the
    /// membership predicate admits has EXACTLY one row, and
    /// every key it excludes has none. The excluded set is
    /// derived (`indexes`), so this cannot drift into a
    /// hand-kept list — what it pins is that the built index
    /// agrees with the predicate, i.e. no key is dropped or
    /// doubled on the way through `build()`.
    @Test("every admitted census key has exactly one row")
    func indexTotality() {
        pinEnglish()
        defer { reset() }
        let rows = SettingsSearchIndex.rows()
        let byKey = Dictionary(
            grouping: rows.compactMap(\.key),
            by: { $0 }
        )
        for key in SettingKey.allCases {
            let count = byKey[key]?.count ?? 0
            if SettingsSearchIndex.indexes(key) {
                #expect(
                    count == 1,
                    "\(key.id): \(count) rows"
                )
            } else {
                #expect(
                    count == 0,
                    "\(key.id) is excluded but indexed"
                )
            }
        }
    }

    /// The tier line: no row for tiers with no Settings surface.
    @Test("lua-only and internal tiers are never indexed")
    func surfacelessTiersExcluded() {
        pinEnglish()
        defer { reset() }
        for row in SettingsSearchIndex.rows() {
            guard let key = row.key else { continue }
            #expect(
                SettingsSearchIndex.indexedTiers.contains(
                    key.placement.tier
                ),
                Comment(rawValue: key.id)
            )
        }
    }

    /// A `.dynamic`-labelled key composes its text per instance,
    /// so it cannot be a static row — and its exclusion is the
    /// predicate's, derived from the census, never a skipped
    /// branch in the builder.
    @Test("dynamic-labelled keys are excluded by the predicate")
    func dynamicLabelsExcluded() {
        for key in SettingKey.allCases
        where key.text.label == .dynamic {
            #expect(
                !SettingsSearchIndex.indexes(key),
                Comment(rawValue: key.id)
            )
        }
    }

    /// Overrides are reachable as LINKS, never as results (spec
    /// item 11): a per-space key — `[space]` in its census id —
    /// is an instance of a setting, and its editor is the
    /// per-space popover no reveal can open, so a result for
    /// one strands the user in an area where the label appears
    /// nowhere (owner, 2026-08-10).
    @Test("per-space instance keys are excluded")
    func perSpaceKeysExcluded() {
        let instanced = SettingKey.allCases.filter {
            $0.id.contains("[space]")
        }
        #expect(!instanced.isEmpty)
        for key in instanced {
            #expect(
                !SettingsSearchIndex.indexes(key),
                Comment(rawValue: key.id)
            )
        }
    }

    /// Search must not return a row that cannot exist on this
    /// machine (#390): the Liquid Glass rows follow the SAME
    /// predicate the renderer hides them by. Asserted through
    /// the predicate so the test states the rule on every
    /// macOS — on 26+ the rows exist, below they do not.
    @Test("platform-hidden rows follow the renderer's predicate")
    func liquidGlassRowsFollowAvailability() {
        pinEnglish()
        defer { reset() }
        let gated = SettingKey.allCases.filter {
            $0.placement.gate?.runtimeConditions
                .contains(.liquidGlassUnavailable) ?? false
        }
        #expect(!gated.isEmpty)
        let indexed = Set(
            SettingsSearchIndex.rows().compactMap(\.key)
        )
        for key in gated {
            #expect(
                indexed.contains(key)
                    == AppBarStyle.glassAvailable,
                Comment(rawValue: key.id)
            )
        }
    }

    /// No control is a search row twice, however it is declared:
    /// a census row that landed on a catalog control claims that
    /// control's id, and the extras are exactly the unclaimed
    /// remainder.
    @Test("no anchor id appears twice in one destination")
    func anchorsUniquePerDestination() {
        pinEnglish()
        defer { reset() }
        let rows = SettingsSearchIndex.rows()
        for destination in SettingsDestination.allCases {
            let anchors = rows.filter {
                $0.destination == destination
            }
            .compactMap(\.anchor.anchor)
            #expect(
                anchors.count == Set(anchors).count,
                "\(destination)"
            )
        }
    }

    /// The census↔catalog label-key join, held by exact
    /// per-destination COUNTS (the three catalog guards'
    /// pattern): a label-key rename on either side silently
    /// strips a census row's scroll anchor — the hit still
    /// opens the destination, the control resurfaces as a
    /// duplicate extras row, and nothing else here can see it
    /// (architect review 2026-08-10). The counts are large on
    /// purpose: the #277 catalog covers a fraction of the
    /// census, and each count FALLS as it fills — update with
    /// the reason stated, never with a floor. Stated residue: a
    /// count cannot see MEMBERSHIP, so an equal-count swap
    /// inside one destination (row A loses its anchor in the
    /// change that gives row B one) passes — granularity, not
    /// coverage.
    @Test("anchor-less census counts match the pinned table")
    func unanchoredCountsArePinned() {
        pinEnglish()
        defer { reset() }
        // The two liquid-glass keys are excluded before
        // counting: they are anchor-less too, but whether they
        // are INDEXED follows `AppBarStyle.glassAvailable`, so
        // counting them would pin this host's macOS answer
        // (`liquidGlassRowsFollowAvailability` owns that axis).
        let anchorless = SettingsSearchIndex.rows()
            .filter { $0.key != nil && $0.anchor.anchor == nil }
            .filter {
                !($0.key?.placement.gate?.runtimeConditions
                    .contains(.liquidGlassUnavailable) ?? false)
            }
        let counts = Dictionary(
            grouping: anchorless,
            by: \.destination
        )
        .mapValues(\.count)
        #expect(
            counts == [
                .spaces: 2,
                .layoutDefaults: 35,
                .monitors: 3,
                .gapsAndBorders: 18,
                .bars: 36,
                .colors: 12,
                .advancedColors: 25,
                // 4 since #1255: the refusal sound moved here
                // from Shortcuts ▸ Size & float, the cue having
                // stopped being a resize setting.
                .behavior: 4,
                // 6: `(action) presets.layouts` joined anchor-less
                // in #859 — the preset card's preview opener. This
                // count RISING is the unusual direction the
                // docstring above warns about, and the reason is
                // that a new census row landed rather than a
                // catalog anchor going missing.
                .profiles: 6,
                // 13: `keybinding.open_settings` joined
                // anchor-less (#678 item 18 — the bindable
                // "Open Settings" row has no #277 catalog
                // anchor yet), and `(action)
                // shortcuts.restore_defaults` joined the same
                // way in #1116 — a new census row landing,
                // not an anchor going missing.
                // 12 since #1255 — the same row leaving.
                .shortcuts: 12,
                .appRules: 3,
                // 11: the backup pair and the other General rows
                // have no #277 catalog anchor (the deleted
                // install inventory card was anchored), and the
                // log export's two rows — the range menu and the
                // button — joined the same way in #1209: new
                // census rows landing, not an anchor going missing.
                .general: 11,
            ]
        )
    }

    /// The catalog-only anchor rows exist — the mode tabs at
    /// least, which the census structurally cannot carry.
    @Test("mode tabs survive as catalog-only rows")
    func modeTabsIndexed() {
        pinEnglish()
        defer { reset() }
        let tabAnchors = SettingsSearchIndex.rows()
            .filter { $0.key == nil }
            .compactMap(\.anchor.anchor)
        for mode in LayoutMode.placementTabs {
            #expect(
                tabAnchors.contains(
                    "layout_mode/\(mode.rawValue)"
                ),
                Comment(rawValue: mode.rawValue)
            )
        }
    }

    /// Every synonym belongs to a key the index carries — an
    /// entry for a key the predicate excludes is dead vocabulary
    /// nothing can ever match.
    @Test("synonyms only decorate indexed keys")
    func synonymsAreLive() {
        pinEnglish()
        defer { reset() }
        for key in SettingKey.allCases
        where !SettingsSearchSynonyms.terms(for: key).isEmpty {
            #expect(
                SettingsSearchIndex.indexes(key),
                Comment(rawValue: key.id)
            )
        }
    }

    /// The enrichment read the shell hands the rows: with the
    /// draft on both sides, the readout's "new" column IS the
    /// current value — pinned here so the search value can never
    /// disagree with the diff narration for the same key.
    @Test("equal-config readout narrates the current value")
    func enrichmentReadsCurrentValue() {
        pinEnglish()
        defer { reset() }
        let config = GuiConfig()
        let row = SettingsValueReadout.rows(
            for: .gaps(.outer),
            old: config,
            new: config
        ).first
        #expect(row?.newValue != nil)
        #expect(row?.newValue == row?.oldValue)
    }

    /// Spec 11a's hard line, as a source scan: the match path —
    /// the index, the builder, the synonyms — never touches the
    /// value readout, the palette store, AX or the filesystem.
    /// Enrichment happens in the ROW view, per visible row, and
    /// the context is collected by the header bar from memory.
    @Test("the match path stays off enrichment and disk")
    func matchPathStaysPure() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let searchCore = [
            "Sources/KiwiDesk/Settings/SettingsSearch.swift",
            "Sources/KiwiDesk/Settings/SettingsSearchIndex.swift",
            "Sources/KiwiDesk/Settings/SettingsSearchSynonyms.swift",
        ]
        let forbidden = [
            "SettingsValueReadout",
            "PaletteStore",
            "AXHelper",
            "FileManager",
            "Data(contentsOf",
        ]
        for path in searchCore {
            let url = root.appendingPathComponent(path)
            let source = SourceScan.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            )
            for needle in forbidden {
                #expect(
                    !source.contains(needle),
                    "\(path) touches \(needle)"
                )
            }
        }
    }
}
