import Foundation
import Testing

@testable import KiwiDeskCore

/// What a backup carries, and what it refuses to read (#606).
///
/// `@MainActor` because `KiwiCore` is; the work is JSON.
@Suite("Setup backup: contents and validation (#606)")
@MainActor
struct SetupBundleTests {
    private func palette(_ name: String) -> ColorPalette {
        ColorPalette(
            name: name,
            colors: [ColorPaletteKeys.all[0]: "#112233"]
        )
    }

    private func profile(_ name: String) -> Profile {
        Profile(
            name: name,
            monitorSets: [MonitorSet(monitors: ["A:100x100"])],
            spaces: [SpaceID("1")],
            spaceModes: [SpaceID("1"): .grid],
            settings: TilingSettings()
        )
    }

    private func write(_ text: String, in core: KiwiCore) throws
        -> URL
    {
        let url = core.configDirectory
            .appendingPathComponent("probe.json")
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - What travels

    @Test("The palette library travels, which gui.json cannot carry")
    func exportCarriesPalettes() throws {
        let core = makeTestCore()
        try core.guiConfigStore.save(GuiConfig())
        try core.paletteLibrary.save(palette("Mine"))

        let bundle = try core.exportSetup()

        // The finding this feature turned on: applying a palette
        // writes its COLOURS into the settings, so the current
        // look rides gui.json — while the saved library lives in
        // palettes.json and would be left behind. The issue's own
        // bundle table guessed the opposite.
        #expect(bundle.palettes.map(\.name) == ["Mine"])
    }

    @Test("Every profile travels")
    func exportCarriesProfiles() throws {
        let core = makeTestCore()
        try core.profiles.save(profile("Desk"))
        try core.profiles.save(profile("Laptop"))

        let names = Set(try core.exportSetup().profiles.map(\.name))
        #expect(names == ["Desk", "Laptop"])
    }

    @Test("A Lua-owned config still backs up what it has")
    func exportWithoutSidecarIsStillUseful() throws {
        let core = makeTestCore()
        try core.profiles.save(profile("Desk"))
        // No gui.json at all — the Lua-managed case, which is
        // ungated by owner ruling rather than hidden.
        #expect(!core.guiConfigStore.exists)

        let bundle = try core.exportSetup()
        #expect(bundle.config == nil)
        #expect(bundle.profiles.count == 1)
        // And it is not "empty", so a restore of it is offered
        // rather than refused.
        #expect(!bundle.isEmpty)
    }

    @Test("The bundle carries these five keys and nothing else")
    func theAllowListIsPinned() throws {
        let core = makeTestCore()
        try core.guiConfigStore.save(GuiConfig())
        // A real init.lua sitting right there, to make the
        // omission a fact about this run rather than about the
        // type in the abstract.
        try "KiwiDesk.set_gap(8)".write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )

        // The WRITTEN file, not a fresh encode: the writer composes
        // the outer document by hand so the header leads, so this
        // is what must be pinned — a field missing from the
        // composer is invisible to an encode of the struct.
        let url = core.configDirectory
            .appendingPathComponent("pinned.json")
        try core.writeBackup(to: url)
        let data = try Data(contentsOf: url)
        let top = try #require(
            try JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        )

        // **Both directions, and the second is why this is not
        // just a literal list.** Reading only the written file
        // catches a key the hand-composer ADDS and is blind to a
        // field it OMITS — which is the one drift hand-composition
        // introduces, and an earlier cut of this test had exactly
        // that hole: adding an optional field to `SetupBundle`
        // that `encodedBackup` skipped left the written file at
        // five keys and the whole suite green, with the field
        // silently never travelling (`code-reviewer`, 2026-08-17).
        //
        // So the file is compared against the type's **stored
        // properties**, by reflection — which `parity-tests.md`
        // prefers over any hand-listed mirror, and which is the
        // only thing that sees this particular omission.
        //
        // Re-encoding the struct is NOT enough and was the first
        // attempt at this fix: `JSONEncoder` omits a nil Optional,
        // so a new `String?` field is absent from the struct's own
        // encoding too and the two key sets still agree. Proven by
        // running that mutation against it.
        let properties = Set(
            Mirror(reflecting: try core.exportSetup()).children
                .compactMap(\.label)
        )
        #expect(
            Set(top.keys) == properties,
            Comment(
                rawValue:
                    "the written file and the type disagree: "
                    + "written \(Set(top.keys).sorted()), stored "
                    + "\(properties.sorted()). A property added to "
                    + "`SetupBundle` owes a line in "
                    + "`encodedBackup`, or it never travels — and "
                    + "if it deliberately should not, it does not "
                    + "belong on the type."
            )
        )
        // And the list itself, so a field added to BOTH still has
        // to argue that it belongs in a backup at all.
        #expect(
            Set(top.keys)
                == [
                    "format", "writtenBy", "config", "profiles",
                    "palettes",
                ]
        )
        let text = String(decoding: data, as: UTF8.self)
        #expect(!text.contains("set_gap"))
        #expect(!text.contains("init.lua"))
    }

    @Test("The header leads: format and writtenBy come first")
    func headerComesFirst() throws {
        let core = makeTestCore()
        try core.guiConfigStore.save(GuiConfig())
        try core.profiles.save(profile("Desk"))
        let url = core.configDirectory
            .appendingPathComponent("ordered.json")

        try core.writeBackup(to: url)
        let lines = try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n")

        // `writtenBy` exists for a human opening the file, and
        // `.sortedKeys` had put it on the last line of 263 (owner,
        // 2026-08-17). Both now sit above the payload.
        let format = try #require(
            lines.firstIndex { $0.contains("\"format\"") }
        )
        let writtenBy = try #require(
            lines.firstIndex { $0.contains("\"writtenBy\"") }
        )
        let config = try #require(
            lines.firstIndex { $0.contains("\"config\"") }
        )
        #expect(format < writtenBy)
        #expect(writtenBy < config)
        #expect(format <= 1)
    }

    @Test("Subtrees stay sorted, so two exports diff cleanly")
    func subtreesStaySorted() throws {
        let core = makeTestCore()
        var config = GuiConfig()
        config.spaces = [SpaceID("b"), SpaceID("a")]
        config.spaceModes = [
            SpaceID("b"): .grid, SpaceID("a"): .monocle,
        ]
        try core.guiConfigStore.save(config)

        // The property the sorting buys and the hand-composed
        // header must not cost: identical input, identical bytes.
        let first = try #require(core.encodedBackup())
        let second = try #require(core.encodedBackup())
        #expect(first == second)
        // And the subtree really is sorted, not merely stable.
        let text = String(decoding: first, as: UTF8.self)
        let appRules = try #require(text.range(of: "\"app_rules\""))
        let spaces = try #require(text.range(of: "\"spaces\""))
        #expect(appRules.lowerBound < spaces.lowerBound)
    }

    /// Dates in a backup read as dates, not as epoch numbers.
    ///
    /// The encoder and decoder must agree, and a round-trip test
    /// cannot see it: two DEFAULT strategies round-trip perfectly
    /// while writing `saved_at` as `776...` — self-consistent, and
    /// the only wrong thing about it is invisible to every
    /// assertion that does not read the file. Found by
    /// hand-writing a backup with the on-disk ISO form and
    /// watching the app refuse it as `.notABackup`.
    @Test("Dates are written the way every other file writes them")
    func datesAreReadable() throws {
        let core = makeTestCore()
        try core.guiConfigStore.save(GuiConfig())
        try core.profiles.save(profile("Desk"))
        let url = core.configDirectory
            .appendingPathComponent("dated.json")

        try core.writeBackup(to: url)
        let text = try String(contentsOf: url, encoding: .utf8)

        // ISO8601, as `ProfileManager` writes it — a `T` and a `Z`
        // inside the quoted value, never a bare number.
        #expect(text.contains("\"saved_at\" : \""))
        #expect(text.contains("T"))
        // And it still reads back, so the pair agrees.
        #expect(try core.readBackup(at: url).profiles.count == 1)
    }

    @Test("A bundle round-trips through JSON unchanged")
    func roundTrips() throws {
        let core = makeTestCore()
        var config = GuiConfig()
        config.spaces = [SpaceID("1"), SpaceID("code")]
        try core.guiConfigStore.save(config)
        try core.profiles.save(profile("Desk"))
        try core.paletteLibrary.save(palette("Mine"))

        let original = try core.exportSetup()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            SetupBundle.self,
            from: data
        )
        #expect(decoded == original)
    }
}
