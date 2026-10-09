import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// What an in-place restart carries across the process swap
/// (#930 ruling 5), by reflection: every stored property of
/// `Space` and of `ManagedWindow` is set away from its default,
/// captured by the in-place stop, crossed through the file's
/// coder and restored into a fresh core — and each one either
/// comes back equal or is named below with the reason it stays
/// behind. A store added tomorrow reds until it is carried or
/// classified; a carried field that stops round-tripping reds
/// too. The parity-tests.md shape, past two mirrors.
@Suite("In-place snapshot carry census (#930)")
@MainActor
struct SnapshotCarryCensusTests {
    private let w1 = WindowID(1)
    private let w2 = WindowID(2)
    private let spaceID = SpaceID("1")

    /// `Space` properties an in-place restart does not carry.
    private let spaceLeftBehind: [String: String] = [
        "handedBreaks":
            "a break's provenance for a departed head's return "
            + "(#1387) — draws nothing, and no head is departed "
            + "across a restart"
    ]

    /// `ManagedWindow` properties the next process's scan reads
    /// again from the app, or that restore replays by a door
    /// of its own.
    private let windowLeftBehind: [String: String] = [
        "pid": "the scan reads the owning process",
        "appName": "the scan reads it",
        "appBundleID": "the scan reads it",
        "title": "the scan reads it",
        "isTransientOverlay": "the scan classifies it",
        "isRaisedLayer": "the scan reads the window layer",
        "isFullscreen": "the scan reads the AX attribute",
        "frame":
            "carried as the record's frame, replayed through "
            + "the frame pipeline rather than as a field",
    ]

    private func fields(_ value: Any) -> [String: String] {
        leaves(value, prefix: "")
    }

    /// Every stored leaf, recursing into the nested session value
    /// types (`SessionRatios`, `ScrollRest` and its slot) so a
    /// field added to one of them is held like a top-level one —
    /// their coding is hand-written (parity-tests.md).
    private func leaves(_ value: Any, prefix: String) -> [String: String] {
        var out: [String: String] = [:]
        for child in Mirror(reflecting: value).children {
            guard let label = child.label else { continue }
            let key = prefix + label
            let nested: Any?
            if let ratios = child.value as? SessionRatios {
                nested = ratios
            } else if let rest = child.value as? ScrollRest {
                nested = rest
            } else if let slot = child.value as? ScrollRest.Slot {
                nested = slot
            } else {
                nested = nil
            }
            if let nested {
                out.merge(leaves(nested, prefix: key + ".")) { a, _ in a }
            } else {
                out[key] = String(describing: child.value)
            }
        }
        return out
    }

    private func tracked(_ core: KiwiCore, _ id: WindowID) {
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: id,
                    pid: 7,
                    appName: "App",
                    title: "t\(id.raw)",
                    frame: CGRect(x: 0, y: 0, width: 400, height: 300)
                )
            )
        )
    }

    /// Process A with every field away from its default.
    private func processA() -> KiwiCore {
        let core = makeTestCore()
        core.state.workspaces.ensureSpace(spaceID)
        core.state.workspaces.activate(spaceID)
        tracked(core, w1)
        tracked(core, w2)
        core.state.workspaces.setMode(spaceID, .track)
        core.state.workspaces.withSpace(spaceID) {
            $0.windows = [self.w2, self.w1]
            $0.focused = self.w1
            $0.stackWeights = [self.w1: 2]
            $0.scrollRest = ScrollRest(
                offset: 40,
                focus: self.w1,
                position: 120,
                restingOn: .trailing
            )
            $0.trackBreaks = [self.w2]
            $0.handedBreaks = [self.w2]
            $0.trackWeights = [self.w2: 1.5]
            $0.sessionRatios.splitRatioH = 0.31
            $0.sessionRatios.splitRatioV = 0.62
            $0.sessionRatios.masterRatio = 0.44
            $0.sessionRatios.slotSize = .fraction(0.712345678)
        }
        core.state.setFloating(w1, true)
        core.state.setSticky(w1, .display)
        core.state.stickyReachOverrides[w1] = false
        core.tiler.monocleShownMembers[spaceID] = w2
        return core
    }

    private func processB(from a: KiwiCore) throws -> KiwiCore {
        let crossed = try JSONDecoder().decode(
            StateSnapshot.self,
            // The in-place stop's whole capture: the hand float
            // rides `stopCarry`, every stop's (#1864).
            from: JSONEncoder().encode(
                try #require(a.crash.stopCapture(inPlace: true))
            )
        )
        let core = makeTestCore()
        core.state.workspaces.ensureSpace(spaceID)
        core.state.workspaces.activate(spaceID)
        tracked(core, w1)
        tracked(core, w2)
        core.restore(crossed)
        return core
    }

    @Test("every Space property is carried or classified")
    func spaceCensus() throws {
        let a = processA()
        let b = try processB(from: a)
        let before = fields(try #require(a.state.workspaces[spaceID]))
        let after = fields(try #require(b.state.workspaces[spaceID]))
        // The baseline carries a default-built scroll rest, so its
        // nested leaves have a default to be moved off — a nil
        // rest has none, and every nested clause passed vacuously.
        var baseline = Space(id: spaceID)
        baseline.scrollRest = ScrollRest(
            offset: 0,
            focus: WindowID(0),
            position: 0,
            restingOn: nil
        )
        let fresh = fields(baseline)
        #expect(
            Set(before.keys).isSubset(of: fresh.keys),
            "a leaf with no default to compare against"
        )
        for (label, value) in before {
            #expect(
                fresh[label] != value || label == "id",
                "fixture leaves \(label) at its default"
            )
            guard spaceLeftBehind[label] == nil else { continue }
            #expect(
                after[label] == value,
                "\(label) did not survive an in-place restart"
            )
        }
        #expect(
            Set(spaceLeftBehind.keys).isSubset(of: before.keys),
            "the register names a property Space no longer has"
        )
    }

    @Test("every window property is carried or classified")
    func windowCensus() throws {
        let a = processA()
        let b = try processB(from: a)
        let before = fields(try #require(a.state.windows[w1]))
        let after = fields(try #require(b.state.windows[w1]))
        let fresh = fields(ManagedWindow(id: w1, pid: 7, appName: "App"))
        for (label, value) in before
        where windowLeftBehind[label] == nil && label != "id" {
            #expect(
                fresh[label] != value,
                "fixture leaves \(label) at its default"
            )
            #expect(
                after[label] == value,
                "\(label) did not survive an in-place restart"
            )
        }
        #expect(
            Set(windowLeftBehind.keys).isSubset(of: before.keys),
            "the register names a property ManagedWindow no longer has"
        )
        #expect(b.state.userFloated.contains(w1))
        #expect(b.state.stickyReachOverrides[w1] == false)
        #expect(b.tiler.monocleShownMembers[spaceID] == w2)
    }

    /// Build N writes, build N+1 reads (#930): a session payload
    /// this build cannot decode costs only itself. The fixture is
    /// the real encoder's output, damaged where another build's
    /// shape would differ — never hand-written JSON.
    @Test("an unreadable session payload costs only itself")
    func unreadablePayloadKeepsTheArrangement() throws {
        let a = processA()
        let snapshot = a.sessionSnapshot(inPlace: true)
        let data = try JSONEncoder().encode(snapshot)
        var json = try #require(
            try JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        )
        var spaces = try #require(json["spaces"] as? [[String: Any]])
        for index in spaces.indices {
            spaces[index]["session"] = ["session_ratios": "wider"]
        }
        json["spaces"] = spaces
        var windows = try #require(json["windows"] as? [[String: Any]])
        for index in windows.indices {
            windows[index]["session"] = ["sticky": "everywhere"]
        }
        json["windows"] = windows
        let damaged = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(
            StateSnapshot.self,
            from: damaged
        )
        #expect(!decoded.carriesSessions)
        // The capture time crossed `JSONSerialization` too; the
        // arrangement is the claim.
        var expected = snapshot.droppingSessions()
        expected.capturedAt = decoded.capturedAt
        #expect(decoded == expected)
        // And the arrangement restores from it.
        let b = makeTestCore()
        b.state.workspaces.ensureSpace(spaceID)
        b.state.workspaces.activate(spaceID)
        tracked(b, w1)
        tracked(b, w2)
        b.restore(decoded)
        let space = try #require(b.state.workspaces[spaceID])
        #expect(space.windows == [w2, w1])
        #expect(space.mode == .track)
        #expect(space.sessionRatios == SessionRatios())
    }

    @Test("a plain capture carries no session memory")
    func plainCaptureCarriesNone() throws {
        let a = processA()
        let data = try JSONEncoder().encode(a.sessionSnapshot())
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(!text.contains("\"session\""))
        let b = makeTestCore()
        b.state.workspaces.ensureSpace(spaceID)
        b.state.workspaces.activate(spaceID)
        tracked(b, w1)
        tracked(b, w2)
        b.restore(
            try JSONDecoder().decode(StateSnapshot.self, from: data)
        )
        let space = try #require(b.state.workspaces[spaceID])
        #expect(space.sessionRatios == SessionRatios())
        #expect(space.stackWeights.isEmpty)
        #expect(b.state.windows[w1]?.isFloating == false)
        #expect(b.state.windows[w1]?.stickyScope == StickyScope.none)
    }
}
