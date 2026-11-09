import Foundation
import Testing

@testable import KiwiDeskCore

/// KiwiVision's maximize as stored (#3064): one `kiwivision.maximize`
/// enum, absent while Off so it owes no crossing, a lens overriding
/// it one row at a time, and its verb refusing what it cannot read.
@Suite("KiwiVision maximize stored (#3064)")
@MainActor
struct KiwiVisionMaximizeStoredTests {
    @Test("Off writes no key; a fill round-trips under maximize")
    func sparse() throws {
        let off = try JSONEncoder().encode(AppWideSettings().vision)
        let offKeys = try #require(
            try JSONSerialization.jsonObject(with: off) as? [String: Any]
        )
        #expect(offKeys["maximize"] == nil)
        var settings = AppWideSettings()
        settings.visionMaximize = .width
        let data = try JSONEncoder().encode(settings.vision)
        let keys = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        #expect(keys["maximize"] as? String == "width")
        let group = try JSONDecoder().decode(
            AppWideSettings.Vision.self,
            from: data
        )
        let back = try #require(
            AppWideSettings(
                refusal: AppWideSettings.Refusal(),
                quit: nil,
                vision: group
            )
        )
        #expect(back.visionMaximize == .width)
    }

    @Test("A lens overrides it; the look resolves the override")
    func lensOverrides() throws {
        let json = #"{"name":"Writing","apps":[],"maximize":"height"}"#
        let lens = try JSONDecoder().decode(
            VisionLens.self,
            from: Data(json.utf8)
        )
        #expect(lens.overrides.maximize == .height)
        var settings = AppWideSettings()
        settings.visionMaximize = .full
        settings.visionLenses = [lens]
        #expect(settings.look(lens: "Writing").maximize == .height)
        #expect(settings.look(lens: nil).maximize == .full)
        let back =
            try JSONSerialization.jsonObject(
                with: JSONEncoder().encode(lens)
            ) as? [String: Any]
        #expect(back?["maximize"] as? String == "height")
    }

    @Test("The verb takes the four spellings and refuses the rest")
    func verb() {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-vfill-\(UUID().uuidString)")
        )
        for fill in VisionMaximize.allCases {
            #expect(
                core.execute(
                    "kiwivision.set_maximize",
                    args: [.string(fill.rawValue)]
                ).isSuccess
            )
            #expect(core.appWide.visionMaximize == fill)
        }
        #expect(
            !core.execute(
                "kiwivision.set_maximize",
                args: [.string("huge")]
            ).isSuccess
        )
        #expect(!core.execute("kiwivision.set_maximize").isSuccess)
    }

    @Test("State asks nothing while KiwiVision is off")
    func offAsksNothing() {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-vfill-\(UUID().uuidString)")
        )
        core.execute("kiwivision.set_maximize", args: [.string("full")])
        #expect(core.state.visionFill.fill == nil)
        core.execute("kiwivision.toggle")
        #expect(core.state.visionFill.fill?.axis == nil)
        #expect(core.state.visionFill.fill != nil)
        core.execute("kiwivision.set_maximize", args: [.string("width")])
        #expect(core.state.visionFill.fill?.axis == .width)
    }
}
