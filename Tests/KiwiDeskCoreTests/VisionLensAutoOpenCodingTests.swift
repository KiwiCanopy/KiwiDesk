import Foundation
import Testing

@testable import KiwiDeskCore

/// A lens's `open_apps` (#3122): a sparse key beside `apps`,
/// pruned to members in the decoder and written only when set, and
/// the one Core door that takes an app out of every per-app list.
@Suite("A lens's Auto-open list (#3122)")
struct VisionLensAutoOpenCodingTests {
    private func decode(_ json: String) throws -> VisionLens {
        try JSONDecoder().decode(VisionLens.self, from: Data(json.utf8))
    }

    @Test("open_apps keys by member, in the members' order")
    func prunedToMembers() throws {
        let lens = try decode(
            #"{"name":"W","apps":["com.a.one","com.b.two"],"#
                + #""open_apps":[" Com.B.Two ","x.y","com.a.one"]}"#
        )
        #expect(lens.openApps == ["com.a.one", "com.b.two"])
    }

    @Test("an absent key reads empty and is written back absent")
    func sparse() throws {
        let lens = try decode(#"{"name":"W","apps":["com.a.one"]}"#)
        #expect(lens.openApps.isEmpty)
        let data = try JSONEncoder().encode(lens)
        let object = try JSONSerialization.jsonObject(with: data)
        #expect((object as? [String: Any])?["open_apps"] == nil)
    }

    @Test("a set list round-trips")
    func roundTrip() throws {
        var lens = VisionLens(name: "W")
        lens.apps = ["com.a.one", "com.b.two"]
        lens.openApps = ["com.b.two"]
        let data = try JSONEncoder().encode(lens)
        let back = try JSONDecoder().decode(VisionLens.self, from: data)
        #expect(back.openApps == ["com.b.two"])
        #expect(back == lens)
    }

    @Test("removing an app clears it from every per-app list")
    func removeAppClearsAll() {
        var lens = VisionLens(name: "W")
        lens.apps = ["com.a.one", "com.b.two"]
        lens.titles = ["com.a.one": ["Docs"]]
        lens.openApps = ["com.a.one", "com.b.two"]
        lens.removeApp("com.a.one")
        #expect(lens.apps == ["com.b.two"])
        #expect(lens.titles.isEmpty)
        #expect(lens.openApps == ["com.b.two"])
    }

    @Test("the switch keeps the members' order")
    func setKeepsOrder() {
        var lens = VisionLens(name: "W")
        lens.apps = ["com.a.one", "com.b.two", "com.c.three"]
        lens.setOpensApp("com.c.three", true)
        lens.setOpensApp("com.a.one", true)
        #expect(lens.openApps == ["com.a.one", "com.c.three"])
        lens.setOpensApp("com.a.one", false)
        #expect(lens.openApps == ["com.c.three"])
    }

    @Test("a titled member and a process-name member cannot open")
    func blocks() {
        var lens = VisionLens(name: "W")
        lens.apps = ["com.a.one", "com.b.two", "my tool"]
        lens.titles = ["com.b.two": []]
        #expect(lens.autoOpenBlock("com.a.one") == nil)
        #expect(lens.autoOpenBlock("com.b.two") == .titled)
        #expect(lens.autoOpenBlock("my tool") == .noBundleID)
        #expect(lens.autoOpenBlock("mytool") == .noBundleID)
    }
}
