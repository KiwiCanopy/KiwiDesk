import Foundation
import Testing

/// Who opens the user motion scope (#804 ▸ Ruling 1). An entry
/// point a KiwiDesk control drives — a Settings action, the quick
/// menu, the tour, a bar click, menu row or drop, a window drag,
/// a scroll gesture — runs its work inside `withUserMotion`; a
/// hotkey and a hold-glide step are read through their own flags.
/// Anything else is ambient, and once the input-quiescence gate
/// lands an entry point missing here makes the user wait for a
/// quiet mouse after their own click. So the map below is the
/// control: per file, today's exact count, with the reason. The
/// CLI/IPC socket is deliberately absent — it is ambient by ruling.
///
/// The scope itself is written in one home: `KiwiCore+MotionCause`
/// (the door and the deferred re-establishment).
@Suite("Motion scope census (#804)")
struct MotionScopeCensusTests {
    private static let sources = SourceScan.repoRoot(
        from: #filePath
    ).appendingPathComponent("Sources")

    /// Path under `Sources` → spellings of `withUserMotion`, a
    /// trailing-closure call included.
    private static let openers: [String: Int] = [
        // The door's own declaration.
        "KiwiDeskCore/App/KiwiCore+MotionCause.swift": 1,
        // App Bar and Space Bar clicks, the divider drag, the App
        // Bar reorder drop.
        "KiwiDeskCore/App/KiwiCore+Bootstrap.swift": 4,
        // A Space Bar glyph pick.
        "KiwiDeskCore/App/KiwiCore+SpaceBarClick.swift": 1,
        // Every bar menu row's action.
        "KiwiDeskCore/App/KiwiCore+BarMenus.swift": 1,
        // The scroll gestures' two consumers.
        "KiwiDeskCore/App/KiwiCore+ScrollPan.swift": 1,
        "KiwiDeskCore/App/KiwiCore+ScrollSpaceStep.swift": 1,
        // The window drag: its moves and its drop, a live display
        // crossing, the Space Bar spring switch.
        "KiwiDeskCore/Tiling/KiwiCore+Drag.swift": 2,
        "KiwiDeskCore/Tiling/KiwiCore+DragCrossing.swift": 1,
        "KiwiDeskCore/Bar/KiwiCore+SpaceBarDrop.swift": 1,
        // The status menu's profile and layout rows, Config
        // Issues' reload and delete.
        "KiwiDesk/AppDelegate.swift": 4,
        // The tour's shelf paint and its revert.
        "KiwiDesk/AppDelegate+OnboardingLooks.swift": 2,
        // Settings: Save and its config reload, load, delete, a
        // preset, a restore, a reset, an app-wide change, a claim,
        // a stored-profile edit, the Lua editor's apply.
        "KiwiDesk/Settings/SettingsModel+Profiles.swift": 5,
        "KiwiDesk/Settings/SettingsModel+Globals.swift": 1,
        "KiwiDesk/Settings/SettingsModel+ProfileOverrides.swift": 1,
        "KiwiDesk/Settings/SettingsModel+Backup.swift": 1,
        "KiwiDesk/Settings/SettingsModel+Reset.swift": 1,
        "KiwiDesk/Settings/SettingsModel+AppWide.swift": 1,
        "KiwiDesk/Settings/SettingsModel+ScreenSetups.swift": 1,
        "KiwiDesk/Settings/SettingsModel+Persistence.swift": 1,
    ]

    @Test("Every user-scope opener is listed, and the list is exact")
    func openersAreRuled() throws {
        let found = try Self.counts(of: "withUserMotion")
        #expect(found.count > 10, "the scan reached too few files")
        for (file, count) in found.sorted(by: { $0.key < $1.key }) {
            let note =
                "\(file) opens the user motion scope \(count) "
                + "time(s) — rule it here (#804)"
            #expect(Self.openers[file] == count, Comment(rawValue: note))
        }
        for (file, count) in Self.openers where found[file] == nil {
            let note =
                "\(file) no longer opens the scope (\(count) listed)"
            Issue.record(Comment(rawValue: note))
        }
    }

    /// The raw scope is reached only by the reader, the door and
    /// the deferred re-establishment, so a cause cannot be forged
    /// at a call site — counted by the property, which an alias
    /// still spells.
    @Test("The scope is entered in its one home")
    func scopeHasOneHome() throws {
        let found = try Self.counts(of: "applier.motion")
        #expect(
            found == ["KiwiDeskCore/App/KiwiCore+MotionCause.swift": 4]
        )
    }

    /// Core doors that move windows when the GUI calls them.
    private static let motionDoors = [
        "execute", "loadConfig", "saveGuiConfig",
        "applyProfileScopedState", "applyStandard", "restoreSetup",
        "restoreShelf", "paintShelf", "reapplyIfInEffect",
        "resetAllSettings", "claimMonitorSet", "commitSharedLook",
        "setAppWide",
    ]

    /// GUI call sites of a motion door left outside the scope on
    /// purpose, by file → count, each with its reason.
    private static let unscopedDoors: [String: Int] = [
        // `set_default_profile` writes a file and moves nothing.
        "KiwiDesk/Settings/SettingsModel+Profiles.swift": 1
    ]

    /// The omission half the opener count cannot see: a GUI call
    /// of a door that moves windows sits inside a `withUserMotion`
    /// closure, or is ruled above.
    @Test("Every GUI motion door runs inside the user scope")
    func guiDoorsAreScoped() throws {
        let gui = Self.sources.appendingPathComponent("KiwiDesk")
        let prefix = Self.sources.path + "/"
        let doors = Self.motionDoors.joined(separator: "|")
        let call = try NSRegularExpression(
            pattern: #"\bcore\.(\#(doors))\("#
        )
        var unscoped: [String: Int] = [:]
        var reached = 0
        for file in try SourceScan.swiftSources(under: gui) {
            let text = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let chars = Array(text.utf16)
            let regions = Self.scopeRegions(in: chars)
            let range = NSRange(location: 0, length: chars.count)
            for match in call.matches(in: text, range: range) {
                reached += 1
                let at = match.range.location
                guard !regions.contains(where: { $0.contains(at) })
                else { continue }
                let key = String(file.path.dropFirst(prefix.count))
                unscoped[key, default: 0] += 1
            }
        }
        #expect(reached > 15, "the scan reached too few door calls")
        #expect(
            unscoped == Self.unscopedDoors,
            "unscoped GUI motion doors: \(unscoped) (#804)"
        )
    }

    /// The brace-balanced body after each `withUserMotion`.
    private static func scopeRegions(
        in chars: [UInt16]
    ) -> [Range<Int>] {
        let needle = Array("withUserMotion".utf16)
        let open = UInt16(UInt8(ascii: "{"))
        let close = UInt16(UInt8(ascii: "}"))
        var regions: [Range<Int>] = []
        var index = 0
        while index + needle.count <= chars.count {
            guard Array(chars[index..<index + needle.count]) == needle
            else {
                index += 1
                continue
            }
            var cursor = index + needle.count
            while cursor < chars.count, chars[cursor] != open {
                cursor += 1
            }
            var depth = 0
            let start = cursor
            while cursor < chars.count {
                if chars[cursor] == open { depth += 1 }
                if chars[cursor] == close {
                    depth -= 1
                    if depth == 0 { break }
                }
                cursor += 1
            }
            regions.append(start..<cursor)
            index += needle.count
        }
        return regions
    }

    private static func counts(
        of needle: String
    ) throws -> [String: Int] {
        let prefix = sources.path + "/"
        var found: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: sources) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let count = source.components(separatedBy: needle).count - 1
            guard count > 0 else { continue }
            found[String(file.path.dropFirst(prefix.count))] = count
        }
        return found
    }
}
