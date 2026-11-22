import Foundation
import Testing

@testable import KiwiDeskCore

// Forget-proof guard for a merge's key rewrite (#3517 ruling 22):
// `GuiConfig.apply(_:)` hand-lists every field that stores an area
// key. An area key is a String, so the scan DISCOVERS every map in
// a `GuiConfig` whose key or value type is `String` by reflection
// (depth 5) and requires each one to be either populated with the
// probe key below — and so rewritten by the merge — or named in
// `notAreaKeyed` with its reason. A new per-screen map reds here
// until it is classified.
//
// Stated limitations: a map whose String sits inside a struct
// element (`[K: SomeStruct]` holding a key in a field) reads as
// neither and escapes the scan; so do a `Set` or an `Array` of
// keys, a map keyed by a typed `ScreenAreaKey`, and an optional
// map left nil, which reflects no children. Such a store owes a
// behavioural test of its own. A profile's other monitor sets
// (`Profile.monitorSets[].spaceMonitorMap`) are outside the draft
// a merge edits: a pin there naming the vanished area falls back
// to area 0 through the one resolver (ruling 22).

private let screen = "Wide:3440x1440"
private let vanished = ScreenAreaKey(fingerprint: screen, areaID: 2)
private let survivor = ScreenAreaKey(fingerprint: screen, areaID: 1)

/// Reflected paths of String-typed maps that hold no area key, and
/// why. Keyed by the whole path, so exempting one map never exempts
/// another of the same name.
private let notAreaKeyed: [String: String] = [
    "appRules": "keyed by app, valued by Space",
    "titledAppRules": "keyed by app and title, valued by Space",
    "settings.spaceIcons": "an SF Symbol name per Space",
    "settings.displayAreas":
        "keyed by the PHYSICAL screen; a merge rewrites its split",
]

/// A config whose every area-keyed field names `vanished`. This
/// population list is the one hand-kept list; the scan
/// cross-checks it against what reflection finds.
private func populated() -> GuiConfig {
    var config = GuiConfig()
    let key = vanished.description
    config.spacePins[SpaceID("1")] = key
    config.settings.spaceBarStyle.edgeOverride[key] = .bottom
    config.settings.appBarStyle.edgeOverride[key] = .left
    config.settings.kiwishelf.pocketEdgeOverride[key] = .right
    return config
}

/// (path, description) of every map typed with `String` on either
/// side, recursing into nested structs.
private func stringMaps(
    _ value: Any,
    path: String = "",
    depth: Int = 5
) -> [(label: String, text: String)] {
    var found: [(String, String)] = []
    for child in Mirror(reflecting: value).children {
        let mirror = Mirror(reflecting: child.value)
        let type = String(describing: type(of: child.value))
        let name = child.label ?? "?"
        let here = path.isEmpty ? name : "\(path).\(name)"
        if mirror.displayStyle == .dictionary {
            if type.contains("<String,") || type.hasSuffix(", String>") {
                found.append((here, "\(child.value)"))
            }
        } else if mirror.displayStyle == .struct, depth > 1 {
            found += stringMaps(child.value, path: here, depth: depth - 1)
        } else if mirror.displayStyle == .optional, depth > 1 {
            found += stringMaps(child.value, path: path, depth: depth - 1)
        }
    }
    return found
}

@Suite("Screen area remap parity (#3517)")
struct ScreenAreaRemapParityTests {
    @Test("every String-typed map is populated or classified")
    func everyMapIsClassified() {
        let maps = stringMaps(populated())
        #expect(maps.count >= 6, "the scan found the maps")
        let key = vanished.description
        for map in maps where notAreaKeyed[map.label] == nil {
            #expect(
                map.text.contains("\"\(key)\""),
                "\(map.label) holds no probe: populate or classify it"
            )
        }
        let labels = Set(maps.map(\.label))
        for label in notAreaKeyed.keys {
            #expect(labels.contains(label), "\(label) is gone")
        }
    }

    @Test("a merge's apply rewrites every area-keyed map")
    func applyRewritesEveryMap() {
        var config = populated()
        config.apply(
            ScreenAreaRemap(vanished: vanished, survivor: survivor)
        )
        let maps = stringMaps(config).filter {
            notAreaKeyed[$0.label] == nil
        }
        #expect(!maps.isEmpty)
        for map in maps {
            #expect(!map.text.contains("\"\(vanished)\""), "\(map.label)")
            #expect(map.text.contains("\"\(survivor)\""), "\(map.label)")
        }
    }

    @Test("a survivor's own edge outranks the vanished one")
    func survivorKeepsItsEdge() {
        var config = populated()
        config.settings.appBarStyle.edgeOverride[survivor.description] =
            .top
        config.apply(
            ScreenAreaRemap(vanished: vanished, survivor: survivor)
        )
        #expect(
            config.settings.appBarStyle.edgeOverride
                == [survivor.description: .top]
        )
    }

    @Test("mergeAreas merges and rewrites through one door")
    func mergeTakesTheDoor() throws {
        var config = populated()
        let whole = ScreenSplit.whole(width: 3440, height: 1440)
        let three = try #require(
            whole.splitting(0, .sideBySide)?.splitting(1, .sideBySide)
        )
        config.settings.displayAreas[screen] = three
        let merged = config.mergeAreas(2, 1, on: screen)
        let remap = try #require(merged)
        #expect(remap.vanished == vanished)
        #expect(remap.survivor == survivor)
        #expect(config.spacePins[SpaceID("1")] == survivor.description)
        #expect(config.settings.displayAreas[screen]?.areas.count == 2)
        let refused = config.mergeAreas(0, 9, on: screen)
        #expect(refused == nil)
    }
}
