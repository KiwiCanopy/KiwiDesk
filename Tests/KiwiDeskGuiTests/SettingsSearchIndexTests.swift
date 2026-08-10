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
