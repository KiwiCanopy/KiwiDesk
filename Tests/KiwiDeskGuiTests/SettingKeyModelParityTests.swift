import CoreGraphics
import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The 4f reflection guard: the profile model and the
/// `SettingKey` census cover each other. This is the net that
/// catches a setting that exists in data but was never given a
/// UI decision — a stored property added to `TilingSettings`
/// (or a new `GuiConfig` field) with no census row reds here,
/// and a census row whose model path no longer exists reds the
/// other way.
@Suite("SettingKey model parity")
struct SettingKeyModelParityTests {
    /// The model instance the walk reflects. Every per-space
    /// override dictionary is seeded with one element so the
    /// walk can descend into its value type. The seeding is a
    /// hand list, but not a silent one: `walkedModel` fails
    /// loudly on any empty dictionary it meets, so a NEW
    /// dictionary in the model demands a seed here instead of
    /// narrowing the walk.
    private static func seededSettings() -> TilingSettings {
        var settings = TilingSettings()
        settings.gapsOverride["1"] = Gaps()
        settings.spaceIcons["1"] = "star"
        settings.placementOverride["1"] = .first
        settings.bsp.override["1"] = BspOverride()
        settings.stack.override["1"] = StackOverride()
        settings.scrolling.override["1"] = ScrollingOverride()
        settings.grid.override["1"] = GridOverride()
        settings.monocle.override["1"] = MonocleOverride()
        settings.track.override["1"] = TrackOverride()
        return settings
    }

    private struct Walk {
        var leaves: Set<String> = []
        var nodes: Set<String> = []
        var emptyDictionaries: [String] = []
    }

    /// Mirror walk in the placement table's path convention:
    /// struct fields become `.name` segments, dictionaries
    /// become `[]`, scalars/enums/collections are leaves.
    private static func walk(
        _ value: Any,
        at path: String,
        into result: inout Walk
    ) {
        if value is Bool || value is Int || value is Double
            || value is CGFloat || value is Float
            || value is String
        {
            result.leaves.insert(path)
            return
        }
        let mirror = Mirror(reflecting: value)
        switch mirror.displayStyle {
        case .optional:
            if let child = mirror.children.first {
                walk(child.value, at: path, into: &result)
            } else {
                result.leaves.insert(path)
            }
        case .dictionary:
            guard let first = mirror.children.first else {
                result.emptyDictionaries.append(path)
                return
            }
            result.nodes.insert(path + "[]")
            let pair = Mirror(reflecting: first.value)
                .children.map(\.value)
            if pair.count == 2 {
                walk(pair[1], at: path + "[]", into: &result)
            }
        case .struct:
            result.nodes.insert(path)
            for child in mirror.children {
                guard let name = child.label else { continue }
                walk(
                    child.value,
                    at: "\(path).\(name)",
                    into: &result
                )
            }
        default:
            // Enums, collections, sets and label-less scalars
            // are leaves in the table's convention.
            result.leaves.insert(path)
        }
    }

    private static func walkedModel() -> Walk {
        var result = Walk()
        walk(seededSettings(), at: "settings", into: &result)
        return result
    }

    /// The census's `settings.*` rows, normalized to the walk's
    /// convention: synthetic `(auto)`/`(unit)`/`(value)`/
    /// `(master)` suffixes stripped, `[space]` → `[]`.
    private static func censusBases() -> Set<String> {
        var bases: Set<String> = []
        for key in SettingKey.allCases {
            var id = key.id
            guard id.hasPrefix("settings.") else { continue }
            for suffix in [
                " (auto)", " (unit)", " (value)", " (master)",
            ] where id.hasSuffix(suffix) {
                id.removeLast(suffix.count)
            }
            bases.insert(
                id.replacingOccurrences(of: "[space]", with: "[]")
            )
        }
        return bases
    }

    /// Model → census: every stored leaf is covered by a row —
    /// its own, or a `[]`-suffixed ancestor row that owns the
    /// whole dictionary object (`settings.gapsOverride[]` owns
    /// its interior). Only dictionary owners get ancestor
    /// coverage: a stripped `(master)` row must NOT own its
    /// subtree, or a field added to `AnimationSettings` or the
    /// `Gaps` pair would need no census row and this direction
    /// would stay green.
    @Test func everyModelLeafHasACensusRow() {
        let walked = Self.walkedModel()
        #expect(
            walked.emptyDictionaries.isEmpty,
            "unseeded dictionaries: \(walked.emptyDictionaries)"
        )
        // Vacuity guard on the walk itself, not a census pin —
        // the census is the set comparison below.
        #expect(walked.leaves.count > 100)
        let bases = Self.censusBases()
        for leaf in walked.leaves {
            let covered =
                bases.contains(leaf)
                || bases.contains {
                    $0.hasSuffix("[]")
                        && leaf.hasPrefix($0 + ".")
                }
            #expect(
                covered,
                "model leaf \(leaf) has no census row"
            )
        }
    }

    /// Census → model: every `settings.*` row still names a
    /// stored leaf or struct node — a renamed or deleted model
    /// property strands its row here.
    @Test func everyCensusRowHasAModelPath() {
        let walked = Self.walkedModel()
        let known = walked.leaves.union(walked.nodes)
        let bases = Self.censusBases()
        // Vacuity pin — an empty census would pass the loop.
        #expect(bases.count > 100)
        for base in bases {
            #expect(
                known.contains(base),
                "census row \(base) names no model path"
            )
        }
    }

    /// The non-settings `GuiConfig` fields and the census's
    /// `config.*` rows cover each other at field granularity
    /// (element sub-rows like `config.spaces[].name` are GUI
    /// affordances over the same storage).
    @Test func guiConfigFieldsAreCensused() {
        var fields: Set<String> = []
        for child in Mirror(reflecting: GuiConfig()).children {
            guard let name = child.label, name != "settings"
            else { continue }
            fields.insert(name)
        }
        #expect(!fields.isEmpty)
        let configIDs = SettingKey.allCases.map(\.id)
            .filter { $0.hasPrefix("config.") }
        for field in fields {
            let covered = configIDs.contains {
                $0 == "config.\(field)"
                    || $0.hasPrefix("config.\(field)[")
                    || $0.hasPrefix("config.\(field).")
            }
            #expect(
                covered,
                "GuiConfig.\(field) has no census row"
            )
        }
        for id in configIDs {
            let body = id.dropFirst("config.".count)
            let head = body.prefix { $0.isLetter || $0.isNumber }
            #expect(
                fields.contains(String(head)),
                "census row \(id) names no GuiConfig field"
            )
        }
    }
}
