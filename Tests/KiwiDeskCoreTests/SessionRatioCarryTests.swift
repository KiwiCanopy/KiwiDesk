import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// An in-place restart carries every Desktop's session sizes
/// (#2921 ruling 1, #930), leaf by leaf, through the file's coder:
/// the per-Desktop half of `SnapshotCarryCensusTests`, whose
/// reflection covers what `Space` stores.
@Suite("In-place carry of per-Desktop sizes (#2921)")
@MainActor
struct SessionRatioCarryTests {
    private let space = SpaceID("1")
    private let desktop: SkyLight.SpaceID = 20

    /// Every `SessionRatios` field away from its default.
    private var fullRatios: SessionRatios {
        var ratios = SessionRatios()
        ratios.splitRatioH = 0.31
        ratios.splitRatioV = 0.62
        ratios.masterRatio = 0.44
        ratios.slotSize = .fraction(0.712345678)
        ratios.gridColumnWeights = [1.25, 0.75, 1]
        ratios.gridRowWeights = [0.6, 1.4]
        return ratios
    }

    private func leaves(_ ratios: SessionRatios) -> [String: String] {
        var out: [String: String] = [:]
        for child in Mirror(reflecting: ratios).children {
            if let label = child.label {
                out[label] = String(describing: child.value)
            }
        }
        return out
    }

    private func processA() -> KiwiCore {
        let core = makeTestCore()
        core.state.workspaces.ensureSpace(space)
        core.state.workspaces.activate(space)
        var shared = SessionRatios()
        shared.masterRatio = 0.58
        core.desktopMemory.sessionRatios = [
            nil: [space: shared],
            desktop: [space: fullRatios],
        ]
        return core
    }

    private func processB(
        _ snapshot: Data,
        shown: SkyLight.SpaceID? = nil
    ) throws -> KiwiCore {
        let core = makeTestCore()
        core.state.workspaces.ensureSpace(space)
        if let shown {
            core.desktopMemory.shownSpaces = ["Main": shown]
            core.desktopMemory.shownUserSpaces = ["Main": true]
        }
        core.restore(
            try JSONDecoder().decode(StateSnapshot.self, from: snapshot)
        )
        return core
    }

    private func captured(_ core: KiwiCore) throws -> Data {
        try JSONEncoder().encode(
            try #require(core.crash.stopCapture(inPlace: true))
        )
    }

    @Test("every Desktop's sizes are carried, leaf by leaf")
    func everyLeafCrosses() throws {
        let b = try processB(try captured(processA()))
        let after = try #require(
            b.desktopMemory.sessionRatios[desktop]?[space]
        )
        let fresh = leaves(SessionRatios())
        for (label, value) in leaves(fullRatios) {
            #expect(fresh[label] != value, "fixture leaves \(label)")
            #expect(
                leaves(after)[label] == value,
                "\(label) did not survive an in-place restart"
            )
        }
        #expect(
            b.desktopMemory.sessionRatios[nil]?[space]?.masterRatio
                == 0.58
        )
    }

    /// A build before #2921 wrote one `session_ratios` per Space;
    /// it lands on the Desktop shown at the restore, which is the
    /// one it was drawn on. The fixture is the real encoder's
    /// output with the per-Desktop list removed.
    @Test("an older record's ratios cross onto the Desktop shown")
    func olderRecordCrosses() throws {
        var json = try #require(
            try JSONSerialization.jsonObject(
                with: try captured(processA())
            ) as? [String: Any]
        )
        var spaces = try #require(json["spaces"] as? [[String: Any]])
        for index in spaces.indices {
            var session = try #require(
                spaces[index]["session"] as? [String: Any]
            )
            #expect(session["desktop_ratios"] != nil)
            session["desktop_ratios"] = nil
            spaces[index]["session"] = session
        }
        json["spaces"] = spaces
        let b = try processB(
            JSONSerialization.data(withJSONObject: json),
            shown: 30
        )
        #expect(b.desktopMemory.sessionRatios[desktop] == nil)
        #expect(b.desktopMemory.sessionRatios[nil] == nil)
        #expect(b.sessionRatios(of: space).masterRatio == 0.58)
    }

    @Test("a plain capture carries no sizes")
    func plainCaptureCarriesNone() throws {
        let b = try processB(
            try JSONEncoder().encode(processA().sessionSnapshot())
        )
        #expect(b.desktopMemory.sessionRatios.isEmpty)
    }
}
