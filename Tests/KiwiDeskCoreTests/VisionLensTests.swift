import Foundation
import Testing

@testable import KiwiDeskCore

/// KiwiVision lenses' stored shape and the one resolver (#2103
/// rulings 23, 28–39): a lens is stored flat in `gui.json`'s
/// `kiwivision.lenses`, an override left out follows the plain
/// setting, and Never dimmed is never a lens's.
@Suite("KiwiVision lens shape")
struct VisionLensTests {
    private func lensWithEverything() -> VisionLens {
        var lens = VisionLens(name: "Writing")
        lens.apps = ["com.apple.preview", "sketchybar"]
        lens.titles = ["com.apple.preview": ["notes"]]
        lens.keepFocus = false
        lens.clearDelay = 3.5
        lens.reminder = "Back to it"
        lens.overrides.dim = 30
        lens.overrides.blur = false
        lens.overrides.appearance = .dark
        lens.overrides.clearWallpaper = true
        lens.overrides.clearApp = true
        return lens
    }

    @Test("a lens round-trips with every field")
    func roundTrip() throws {
        let lens = lensWithEverything()
        expectAllChanged(lens, from: VisionLens(name: "x"))
        expectAllChanged(lens.overrides, from: VisionLens.Overrides())
        let back = try JSONDecoder().decode(
            VisionLens.self,
            from: JSONEncoder().encode(lens)
        )
        #expect(back == lens)
    }

    @Test("a sparse lens follows every default, and decode clamps")
    func sparseDecode() throws {
        let json =
            #"{"name":"Reading","apps":[" Com.Apple.Safari "],"#
            + #""clear_delay":-4,"dim":250}"#
        let lens = try JSONDecoder().decode(
            VisionLens.self,
            from: Data(json.utf8)
        )
        #expect(lens.apps == ["com.apple.safari"])
        #expect(lens.keepFocus)
        #expect(lens.clearDelay == 0)
        #expect(lens.overrides.dim == 100)
        #expect(lens.overrides.blur == nil)
        #expect(lens.reminder == nil)
        let strict = #"{"name":"R","appearance":"sepia"}"#
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(
                VisionLens.self,
                from: Data(strict.utf8)
            )
        }
    }

    /// The overrides mirror the stored group's settings, less what
    /// a lens never overrides.
    @Test("the overrides mirror the plain settings")
    func overrideParity() {
        let plain = fieldNames(AppWideSettings().vision)
            .subtracting(["neverDimmed", "lenses"])
        #expect(fieldNames(VisionLens.Overrides()) == plain)
    }

    @Test("the resolver applies every override, and plain otherwise")
    func resolverAppliesEveryField() {
        var settings = AppWideSettings()
        settings.visionNeverDimmed = ["sketchybar"]
        settings.visionLenses = [lensWithEverything()]
        let plain = settings.look(lens: nil)
        let lensed = settings.look(lens: "writing")
        expectResolvesEveryField(
            resolved: lensed,
            base: plain,
            covered: fieldNames(VisionLens.Overrides())
                .union(["lens"])
        )
        #expect(lensed.neverDimmed == plain.neverDimmed)
        #expect(settings.look(lens: "Nope") == plain)
    }

    /// An override is spelled in JSON as the plain setting it
    /// overrides, so a renamed key reds here.
    @Test("an override's JSON key is the plain setting's")
    func overrideKeys() throws {
        func keys(_ value: some Encodable) throws -> Set<String> {
            let object = try JSONSerialization.jsonObject(
                with: JSONEncoder().encode(value)
            )
            return Set((object as? [String: Any] ?? [:]).keys)
        }
        var plain = AppWideSettings().vision
        plain.neverDimmed = []
        plain.lenses = []
        let stored = try keys(plain)
            .subtracting(["never_dimmed", "lenses"])
        #expect(!stored.isEmpty)
        #expect(stored.isSubset(of: try keys(lensWithEverything())))
    }

    @Test("titles key by member, names are cut and looked up trimmed")
    func normalisedKeys() throws {
        let json =
            #"{"name":"  Writing  ","apps":["com.apple.preview"],"#
            + #""titles":{" Com.Apple.Preview ":["notes"],"x":["y"]}}"#
        var settings = AppWideSettings()
        settings.visionLenses = AppWideSettings.lensEntries([
            try JSONDecoder().decode(
                VisionLens.self,
                from: Data(json.utf8)
            ),
            VisionLens(name: String(repeating: "a", count: 60)),
        ])
        let lens = try #require(settings.lens(named: " writing\n"))
        #expect(lens.titles == ["com.apple.preview": ["notes"]])
        #expect(
            settings.visionLenses.last?.name.count
                == AppWideSettings.lensNameLimit
        )
    }

    @Test("gui.json carries the lenses, names unique ignoring case")
    func storedGroup() throws {
        var settings = AppWideSettings()
        settings.visionLenses = [
            lensWithEverything(), VisionLens(name: " writing "),
            VisionLens(name: "  "), VisionLens(name: "Reading"),
        ]
        var config = GuiConfig()
        config.appWide = settings
        let back = try JSONDecoder().decode(
            GuiConfig.self,
            from: JSONEncoder().encode(config)
        )
        #expect(
            back.appWide?.visionLenses.map(\.name) == ["Writing", "Reading"]
        )
        #expect(back.appWide?.visionLenses.first == lensWithEverything())
    }
}
