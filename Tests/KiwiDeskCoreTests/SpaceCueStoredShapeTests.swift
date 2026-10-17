import Foundation
import Testing

@testable import KiwiDeskCore

/// `space.cue` in `gui.json` (#2228): written beside `desktop.cue`
/// and `mode.cue`, round-tripped, and read on where a file written
/// before it carries no `space` group — the shape
/// `ModeCycleCueTests` ▸ `storedShape` holds for its sibling.
@Suite("Space cue stored shape (#2228)")
struct SpaceCueStoredShapeTests {
    @Test("gui.json carries space.cue, and its absence reads on")
    func storedShape() throws {
        var config = GuiConfig()
        var value = AppWideSettings()
        value.spaceCue = false
        config.appWide = value
        let data = try JSONEncoder().encode(config)
        let root = try #require(
            try JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        )
        let group = try #require(root["space"] as? [String: Any])
        #expect(group["cue"] as? Bool == false)
        let back = try JSONDecoder().decode(GuiConfig.self, from: data)
        #expect(back.appWide?.spaceCue == false)
        var older = root
        older["space"] = nil
        let legacy = try JSONDecoder().decode(
            GuiConfig.self,
            from: JSONSerialization.data(withJSONObject: older)
        )
        #expect(legacy.appWide?.spaceCue == true)
    }
}
