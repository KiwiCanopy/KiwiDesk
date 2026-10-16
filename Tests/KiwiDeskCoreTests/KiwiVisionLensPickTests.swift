import Foundation
import Testing

@testable import KiwiDeskCore

/// KiwiHub's lens chips (#2103 ruling 41) turn a lens on through
/// `setKiwiVision(lens:)`: a pick, never a toggle, so the lens
/// already on stays on, and a lens with no apps or no lens at all
/// refuses (ruling 37).
@Suite("KiwiVision lens pick")
@MainActor
struct KiwiVisionLensPickTests {
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-vision-pick-\(UUID().uuidString)"
                )
        )
        core.eventLoop.ownKeyWindow = { nil }
        for (name, apps) in [("Writing", ["test.kiwi.notes"]), ("Empty", [])] {
            let lens: [String: JSONValue] = [
                "name": .string(name),
                "apps": .array(apps.map { .string($0) }),
            ]
            #expect(
                core.execute("kiwivision.define_lens", args: [.object(lens)])
                    .isSuccess
            )
        }
        return core
    }

    @Test("a pick turns a lens on from off or plain, and keeps it on")
    func pickTurnsOn() {
        let core = makeCore()
        var heard: [VisionActive] = []
        core.vision.onChange = { heard.append($0) }
        core.setKiwiVision(lens: "writing")
        #expect(core.kiwiVisionActive == .lens("Writing"))
        // A pick of the lens on is no toggle.
        core.setKiwiVision(lens: "Writing")
        #expect(core.kiwiVisionActive == .lens("Writing"))
        core.setKiwiVision(true)
        #expect(core.kiwiVisionActive == .plain)
        core.setKiwiVision(lens: "Writing")
        #expect(core.kiwiVisionActive == .lens("Writing"))
        #expect(heard == [.lens("Writing"), .plain, .lens("Writing")])
    }

    @Test("an empty or unknown lens refuses the pick")
    func refusals() {
        let core = makeCore()
        core.setKiwiVision(lens: "Empty")
        core.setKiwiVision(lens: "Nope")
        #expect(core.kiwiVisionActive == .off)
        core.setKiwiVision(lens: "Writing")
        core.setKiwiVision(lens: "Empty")
        #expect(core.kiwiVisionActive == .lens("Writing"))
    }
}
