import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// SPIKE for #792, never merges: per census model-path key, can a
/// Codable splice reach its leaf? The splice reads the encoded
/// JSON by wire key, the diff names leaves by Swift property, so
/// the question is whether a per-segment camelCase→snake_case
/// translation of the key's base lands on a key the encoder
/// writes. Writes its report to the job scratch dir.
@Suite("Spike 792 census")
struct Spike792CensusTests {
    static let out = URL(
        fileURLWithPath:
            "/Users/maikelhajiabadi/.claude/jobs/8f513128/tmp/spike792.txt"
    )

    private func seeded() -> GuiConfig {
        var config = GuiConfig()
        config.settings.gapsOverride["1"] = Gaps()
        config.settings.spaceIcons["1"] = "star"
        config.settings.placementOverride["1"] = .first
        config.settings.bsp.override["1"] = BspOverride()
        config.settings.stack.override["1"] = StackOverride()
        config.settings.scrolling.override["1"] = ScrollingOverride()
        config.settings.grid.override["1"] = GridOverride()
        config.settings.monocle.override["1"] = MonocleOverride()
        config.settings.track.override["1"] = TrackOverride()
        config.settings.spaceBarStyle.edgeOverride["S:1x1"] = .left
        config.settings.appBarStyle.edgeOverride["S:1x1"] = .left
        config.spaces = ["work"]
        config.spaceModes = ["work": .grid]
        config.appRules = ["Safari": "web"]
        config.spacePins = ["work": "fp"]
        config.mainSpaces = ["work"]
        config.fallbackSpace = "work"
        config.floatRules = ["Info"]
        config.ignoreRules = ["Helper"]
        return config
    }

    private func snake(_ s: String) -> String {
        var out = ""
        for c in s {
            if c.isUppercase {
                out += "_" + c.lowercased()
            } else {
                out.append(c)
            }
        }
        return out
    }

    /// Walks `segments` (instances as "[]") into `json`, snake-cased.
    private func reaches(_ segments: [String], _ json: JSONValue) -> Bool {
        var node = json
        for seg in segments {
            guard case .object(let map) = node else { return false }
            if seg == "[]" {
                guard let first = map.values.first else { return false }
                node = first
                continue
            }
            let key = map[seg] != nil ? seg : snake(seg)
            guard let next = map[key] else { return false }
            node = next
        }
        return true
    }

    private func segments(_ base: String) -> [String] {
        var parts: [String] = []
        for piece in base.split(separator: ".") {
            var p = String(piece)
            var tail: [String] = []
            while p.hasSuffix("[]") {
                p.removeLast(2)
                tail.append("[]")
            }
            parts.append(p)
            parts += tail
        }
        return parts
    }

    @Test func report() throws {
        let config = seeded()
        let settings = try #require(JSONValue(encoding: config.settings))
        let gui = try #require(JSONValue(encoding: config))
        var lines: [String] = []
        var counts: [String: Int] = [:]
        var bases: [String: [SettingKey]] = [:]
        for (base, key) in SettingsDraftDiff.censusBases() {
            bases[base, default: []].append(key)
        }
        for key in SettingKey.allCases {
            guard SettingsDraftDiff.namesModelPath(key.id) else {
                counts["notModelPath", default: 0] += 1
                continue
            }
            var id = key.id
            for s in [" (auto)", " (unit)", " (value)", " (master)"]
            where id.hasSuffix(s) { id.removeLast(s.count) }
            for i in ["[space]", "[app]", "[n]", "[screen]"] {
                id = id.replacingOccurrences(of: i, with: "[]")
            }
            let verdict: String
            if id.hasPrefix("settings.") {
                let segs = segments(String(id.dropFirst(9)))
                verdict = reaches(segs, settings)
                    ? "settings.splice" : "settings.MISS"
            } else {
                let segs = segments(String(id.dropFirst(7)))
                verdict = reaches(segs, gui)
                    ? "config.splice" : "config.notEncoded"
            }
            counts[verdict, default: 0] += 1
            lines.append("\(verdict)\t\(key.id)")
        }
        let total = counts.values.reduce(0, +)
        var report = "#792 spike, \(Date())\n"
        report += "SettingKey.allCases: \(total)\n"
        for (k, v) in counts.sorted(by: { $0.key < $1.key }) {
            report += "  \(k): \(v)\n"
        }
        report += "distinct normalized bases: \(bases.count)\n\n"
        report += lines.sorted().joined(separator: "\n") + "\n"
        try report.write(to: Self.out, atomically: true, encoding: .utf8)
    }
}
