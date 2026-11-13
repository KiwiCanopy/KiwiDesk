import Foundation
import Testing

@testable import KiwiDeskCore

/// 4.2 upgraders move to Medium (#3254 ▸ Ruling amendment): at
/// #3237's crossing, an install whose profile carries 4.2's four
/// lengths and whose `gui.json` carries 4.2's slide and fade crosses
/// onto Medium's table; any other value is a choice and stays, the
/// four moving only with the two. A length the capture lacks reads
/// 4.2's default, which its absence meant.
@Suite("Pace crossing to Medium (#3254)", .serialized)
@MainActor
struct PaceMediumCrossingTests {
    private func directory() -> URL {
        testTemporaryDirectory
            .appendingPathComponent("kiwi-medium-\(UUID().uuidString)")
    }

    /// A core whose `gui.json` is 4.2's: crossed #1741, no pace
    /// group, the slide and fade stored.
    private func make42Core(slide: Int, fade: Int) throws -> KiwiCore {
        let core = makeTestCore(configDirectory: directory())
        var config = GuiConfig()
        var wide = AppWideSettings()
        wide.spaceSlideDuration = slide
        wide.visionFadeDuration = fade
        wide.animationPaceStored = false
        config.appWide = wide
        try core.guiConfigStore.save(config)
        try restamp(core.guiConfigStore.url, to: Self.guiFormat42)
        return core
    }

    /// 4.2.1's shipped formats, spelled as history.
    private static let profileFormat42 = 34
    private static let guiFormat42 = 19
    private static let bundleFormat42 = 43

    private func restamp(_ url: URL, to format: Int) throws {
        var root = try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: url))
                as? [String: Any]
        )
        root["format"] = format
        try JSONSerialization.data(withJSONObject: root).write(to: url)
    }

    /// Saves `name` as a 4.2 file carrying `lengths`, nil leaving a
    /// key out.
    private func save42(
        _ name: String,
        _ lengths: [String: Int?],
        in core: KiwiCore
    ) throws {
        try core.profiles.save(
            Profile(
                name: name,
                monitorSets: [MonitorSet(monitors: ["A:100x100"])],
                spaceModes: [:],
                settings: TilingSettings()
            )
        )
        let url = try core.profiles.fileURL(name: name)
        var root = try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: url))
                as? [String: Any]
        )
        var settings = try #require(root["settings"] as? [String: Any])
        var animations = try #require(
            settings["animations"] as? [String: Any]
        )
        for (key, value) in lengths { animations[key] = value }
        settings["animations"] = animations
        root["settings"] = settings
        root["format"] = Self.profileFormat42
        try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys]
        ).write(to: url)
    }

    private static let legacy: [String: Int?] = [
        "duration": 150, "scroll_duration": 150,
        "expand_duration": 750, "reveal_duration": 300,
    ]

    /// A launch's load, then the profile applied: the crossing ends
    /// and `gui.json` stores the group it was owed.
    private func cross(_ core: KiwiCore) {
        #expect(
            core.guiConfigStore.load()?.appWide?.animationPaceStored != true
        )
        core.loadConfig()
        #expect(
            core.execute("load_profile", args: [.string("Work")]).isSuccess
        )
        #expect(core.appWideLedger.owedPace == nil)
        #expect(
            core.guiConfigStore.load()?.appWide?.animationPaceStored == true
        )
    }

    @Test("4.2's six lengths cross onto Medium")
    func untouchedMovesToMedium() throws {
        let core = try make42Core(slide: 300, fade: 300)
        try save42("Work", Self.legacy, in: core)
        cross(core)
        #expect(AnimationPacePreset.current(of: core.appWide) == .medium)
        #expect(
            core.tiler.animation.durationMS
                == AnimationPacePreset.shipped.window
        )
        let stored = try #require(core.guiConfigStore.load()?.appWide)
        #expect(stored.paceTable == AnimationPacePreset.shipped)
    }

    /// One length off 4.2's, in either file, is a choice: every value
    /// stays and the speed reads Custom.
    @Test(
        "one length off 4.2's keeps every value",
        arguments: [
            "duration", "scroll_duration", "expand_duration",
            "reveal_duration", "slide", "fade",
        ]
    )
    func oneOffKeepsEveryValue(_ length: String) throws {
        let core = try make42Core(
            slide: length == "slide" ? 500 : 300,
            fade: length == "fade" ? 500 : 300
        )
        var lengths = Self.legacy
        if lengths[length] != nil { lengths[length] = 600 }
        try save42("Work", lengths, in: core)
        cross(core)
        let table = core.appWide.paceTable
        let legacy = AnimationPacePreset.legacyDefaults
        let off = [
            "duration": table.window != legacy.window,
            "scroll_duration": table.scroll != legacy.scroll,
            "expand_duration": table.expand != legacy.expand,
            "reveal_duration": table.reveal != legacy.reveal,
            "slide": table.slide != legacy.slide,
            "fade": table.fade != legacy.fade,
        ]
        #expect(off.filter(\.value).map(\.key) == [length])
        #expect(AnimationPacePreset.current(of: core.appWide) == nil)
    }

    /// A key the 4.2 file left out meant 4.2's default, never the
    /// moved one, so it still counts toward the match.
    @Test("an absent length reads 4.2's default")
    func absentReadsLegacy() throws {
        let core = try make42Core(slide: 300, fade: 300)
        var lengths = Self.legacy
        lengths["expand_duration"] = Int??.some(nil)
        try save42("Work", lengths, in: core)
        cross(core)
        #expect(AnimationPacePreset.current(of: core.appWide) == .medium)
    }

    /// No crossing owed, no move: a `gui.json` that stores the group
    /// keeps a 4.2-shaped table as Custom.
    @Test("a stored group is never moved")
    func storedGroupStays() throws {
        let core = makeTestCore(configDirectory: directory())
        var config = GuiConfig()
        var wide = AppWideSettings()
        wide.animationDurationMS = 150
        wide.animationScrollDurationMS = 150
        wide.animationExpandDurationMS = 750
        wide.animationRevealDurationMS = 300
        wide.spaceSlideDuration = 300
        wide.visionFadeDuration = 300
        config.appWide = wide
        try core.guiConfigStore.save(config)
        core.prepareAppWide()
        #expect(core.appWideLedger.owedPace == nil)
        #expect(
            core.appWide.paceTable == AnimationPacePreset.legacyDefaults
        )
    }

    /// A 4.2 backup carrying `lengths` in its inline profile and
    /// 4.2's slide and fade in its config, restored end to end.
    private func restore42Backup(
        _ lengths: [String: Int?]
    ) throws -> KiwiCore {
        let core = makeTestCore(configDirectory: directory())
        try core.guiConfigStore.save(GuiConfig())
        var config = GuiConfig()
        var wide = AppWideSettings()
        wide.spaceSlideDuration = 300
        wide.visionFadeDuration = 300
        wide.animationPaceStored = false
        config.appWide = wide
        let bundle = SetupBundle(
            writtenBy: "4.2",
            config: config,
            profiles: [
                Profile(
                    name: "Work",
                    monitorSets: [MonitorSet(monitors: ["A:100x100"])],
                    spaceModes: [:],
                    settings: TilingSettings()
                )
            ],
            palettes: []
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var root = try #require(
            JSONSerialization.jsonObject(with: encoder.encode(bundle))
                as? [String: Any]
        )
        var profiles = try #require(root["profiles"] as? [[String: Any]])
        var settings = try #require(
            profiles[0]["settings"] as? [String: Any]
        )
        var animations = try #require(
            settings["animations"] as? [String: Any]
        )
        for (key, value) in lengths { animations[key] = value }
        settings["animations"] = animations
        profiles[0]["settings"] = settings
        profiles[0]["format"] = Self.profileFormat42
        root["profiles"] = profiles
        root["format"] = Self.bundleFormat42
        let url = directory().appendingPathExtension("json")
        try JSONSerialization.data(withJSONObject: root).write(to: url)
        let read = try core.readBackup(at: url)
        try core.restoreSetup(from: read) { _ in }
        #expect(
            core.execute("load_profile", args: [.string("Work")]).isSuccess
        )
        return core
    }

    /// A 4.2 backup crosses at the restore's adoption the same way:
    /// its inline profile carries the four, its config the two.
    @Test("a 4.2 backup's six lengths cross onto Medium")
    func backupMovesToMedium() throws {
        let core = try restore42Backup(Self.legacy)
        #expect(AnimationPacePreset.current(of: core.appWide) == .medium)
    }

    /// The backup's own capture survives the restore's reload: a
    /// chosen length in the inline profile keeps every value.
    @Test("a 4.2 backup's chosen length keeps every value")
    func backupKeepsAChosenLength() throws {
        var lengths = Self.legacy
        lengths["duration"] = 600
        let core = try restore42Backup(lengths)
        #expect(core.appWide.animationDurationMS == 600)
        #expect(AnimationPacePreset.current(of: core.appWide) == nil)
    }

    /// A `gui.json` from before the `space` and `kiwivision` groups
    /// left the slide and the fade out, which meant 300 ms then, so
    /// they still count toward 4.2's six.
    @Test("an absent slide and fade read 4.2's")
    func absentSlideAndFadeReadLegacy() throws {
        let core = try make42Core(slide: 300, fade: 300)
        let url = core.guiConfigStore.url
        var root = try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: url))
                as? [String: Any]
        )
        root["space"] = nil
        root["kiwivision"] = nil
        try JSONSerialization.data(withJSONObject: root).write(to: url)
        try save42("Work", Self.legacy, in: core)
        cross(core)
        #expect(AnimationPacePreset.current(of: core.appWide) == .medium)
    }

    /// With no capture — a composed Standard, which 4.2 ran at its
    /// defaults, or an uncaptured profile — the four read 4.2's, which
    /// their absence meant.
    @Test("no capture beside 4.2's pair moves to Medium")
    func noCaptureBesideLegacyPairMoves() throws {
        let core = try make42Core(slide: 300, fade: 300)
        try save42("Work", Self.legacy.mapValues { _ in Int?.none }, in: core)
        cross(core)
        #expect(AnimationPacePreset.current(of: core.appWide) == .medium)
    }

    /// A chosen slide with no capture keeps every value, the four at
    /// 4.2's: never split per file.
    @Test("no capture beside a chosen slide keeps every value")
    func noCaptureKeepsEveryValue() throws {
        let core = try make42Core(slide: 500, fade: 300)
        try save42("Work", Self.legacy.mapValues { _ in Int?.none }, in: core)
        cross(core)
        let legacy = AnimationPacePreset.legacyDefaults
        #expect(core.appWide.animationDurationMS == legacy.window)
        #expect(core.appWide.spaceSlideDuration == 500)
        #expect(AnimationPacePreset.current(of: core.appWide) == nil)
    }

    /// A `gui.json` from before #1741 stores no app-wide group, so its
    /// slide and fade read 4.2's beside the profile's captured four.
    @Test("a pre-#1741 install crosses whole")
    func pre1741CrossesWhole() throws {
        let core = makeTestCore(configDirectory: directory())
        try core.guiConfigStore.save(GuiConfig())
        try restamp(core.guiConfigStore.url, to: Self.guiFormat42)
        try save42("Work", Self.legacy, in: core)
        cross(core)
        #expect(AnimationPacePreset.current(of: core.appWide) == .medium)
    }

    /// A fresh install's second launch: `gui.json` stores no app-wide
    /// groups and its profile carries no lengths, so nothing is
    /// captured and it keeps Medium.
    @Test("a fresh install keeps Medium")
    func freshInstallKeepsMedium() throws {
        let core = makeTestCore(configDirectory: directory())
        try core.guiConfigStore.save(GuiConfig())
        try core.profiles.save(
            Profile(
                name: "Work",
                monitorSets: [MonitorSet(monitors: ["A:100x100"])],
                spaceModes: [:],
                settings: TilingSettings()
            )
        )
        cross(core)
        #expect(AnimationPacePreset.current(of: core.appWide) == .medium)
    }
}
