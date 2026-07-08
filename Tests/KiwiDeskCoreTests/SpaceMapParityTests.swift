import Foundation
import Testing

@testable import KiwiDeskCore

// Forget-proof guard for the per-space map list (#68,
// AGENTS.md §5 parity rule): `TilingSettings.renameSpace` and
// `removeSpace` each hand-enumerate every `[SpaceID: _]` map.
// These tests DISCOVER the maps by reflection (depth 2, so the
// per-layout `override` maps inside the param structs count),
// so adding a ninth map without touching both functions — or
// without populating it below — fails red instead of silently
// orphaning entries.

private let probe = SpaceID("parityProbe")
private let renamed = SpaceID("parityRenamed")

/// A settings value with EVERY per-space map holding an entry
/// for the probe space. This population list is the single
/// hand-kept list; `dictionaryCount` cross-checks it against
/// the reflected map count, so a new map missing here is
/// itself a red test.
private func populated() -> TilingSettings {
    var settings = TilingSettings()
    settings.gapsOverride[probe] = .uniform(4)
    settings.placementOverride[probe] = .first
    settings.spaceIcons[probe] = "globe"
    settings.bsp.override[probe] = BspOverride()
    settings.stack.override[probe] = StackOverride()
    settings.scrolling.override[probe] = ScrollingOverride()
    settings.grid.override[probe] = GridOverride()
    settings.monocle.override[probe] = MonocleOverride()
    return settings
}

/// String descriptions of every dictionary-typed stored
/// property, recursing into nested structs (the per-layout
/// params hold their `override` maps at depth 2; the extra
/// levels are headroom so a map inside a future sub-struct
/// can't silently escape the net).
private func dictionaryDescriptions(
    _ value: Any,
    depth: Int = 4
) -> [String] {
    var found: [String] = []
    for child in Mirror(reflecting: value).children {
        let mirror = Mirror(reflecting: child.value)
        if mirror.displayStyle == .dictionary {
            found.append(String(describing: child.value))
        } else if mirror.displayStyle == .struct, depth > 1 {
            found += dictionaryDescriptions(
                child.value,
                depth: depth - 1
            )
        }
    }
    return found
}

@Suite("Per-space map parity (#68)")
struct SpaceMapParityTests {
    @Test("the population list covers every reflected map")
    func populationIsExhaustive() {
        let dicts = dictionaryDescriptions(populated())
        let holding = dicts.filter {
            $0.contains(probe.raw)
        }
        // Every dictionary in TilingSettings is keyed by
        // SpaceID; a new one that the population list misses
        // shows up as a dict without the probe entry.
        #expect(!dicts.isEmpty)
        #expect(holding.count == dicts.count)
    }

    @Test("renameSpace migrates every per-space map")
    func renameCoversEveryMap() {
        var settings = populated()
        settings.renameSpace(from: probe, to: renamed)
        let dicts = dictionaryDescriptions(settings)
        #expect(
            !dicts.contains { $0.contains(probe.raw) }
        )
        #expect(
            dicts.filter { $0.contains(renamed.raw) }.count
                == dicts.count
        )
    }

    @Test("removeSpace clears every per-space map")
    func removeCoversEveryMap() {
        var settings = populated()
        settings.removeSpace(probe)
        let dicts = dictionaryDescriptions(settings)
        #expect(
            !dicts.contains { $0.contains(probe.raw) }
        )
    }
}
