import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// `list_monitors` reports each screen's origin in the AX
/// coordinates `list_windows` uses (#2492): top-left, y down,
/// measured from the screen AppKit's origin sits on. A screen
/// above the main one reads a NEGATIVE y, where a flip that
/// measured from the wrong screen goes wrong.
@Suite("list_monitors origins", .serialized)
@MainActor
struct ListMonitorsOriginTests {
    private func origins(
        _ displays: [Display]
    ) throws -> [UInt32: (x: Double, y: Double)] {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "kiwidesk-list-monitors-\(UUID().uuidString)"
                )
        )
        core.state.apply(.displaysChanged(displays))
        let response = core.execute("list_monitors")
        guard case .array(let list)? = response.data else {
            Issue.record("list_monitors answered \(response)")
            return [:]
        }
        var byID: [UInt32: (x: Double, y: Double)] = [:]
        for entry in list {
            guard case .object(let monitor) = entry else { continue }
            let id = try #require(monitor["id"]?.numberValue)
            let x = try #require(monitor["x"]?.numberValue)
            let y = try #require(monitor["y"]?.numberValue)
            byID[UInt32(id)] = (x, y)
        }
        return byID
    }

    @Test("A screen above or beside the main one reads top-left")
    func originsAreTopLeft() throws {
        let main = Display(
            id: DisplayID(1),
            name: "Main",
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080)
        )
        // AppKit's y grows up: this one sits on top of the main.
        let above = Display(
            id: DisplayID(2),
            name: "Above",
            frame: CGRect(x: 200, y: 1080, width: 1600, height: 900)
        )
        let left = Display(
            id: DisplayID(3),
            name: "Left",
            frame: CGRect(x: -1440, y: 0, width: 1440, height: 900)
        )
        let seen = try origins([above, main, left])
        #expect(seen[1]?.x == 0)
        #expect(seen[1]?.y == 0)
        #expect(seen[2]?.x == 200)
        #expect(seen[2]?.y == -900)
        #expect(seen[3]?.x == -1440)
        #expect(seen[3]?.y == 180)
    }
}
