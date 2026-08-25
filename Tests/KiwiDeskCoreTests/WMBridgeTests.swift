import Foundation
import Testing

@testable import KiwiDeskCore

// MARK: - Fake operation classes

/// What the fakes below saw: the arguments each initialiser
/// received and how many operations were dispatched. Reset per
/// test; the suite is serialized because this and the resolver
/// seam are process-global.
private enum Seen {
    nonisolated(unsafe) static var displayIdentifier: String?
    nonisolated(unsafe) static var windows: [NSNumber] = []
    nonisolated(unsafe) static var spaceID: UInt64 = 0
    nonisolated(unsafe) static var performed = 0
    nonisolated(unsafe) static var requested: [String] = []

    static func reset() {
        displayIdentifier = nil
        windows = []
        spaceID = 0
        performed = 0
        requested = []
    }
}

/// A result object shaped like the bridge's own: one declared
/// property, read by key.
private final class FakeSpaceIDResult: NSObject {
    @objc let spaceID: UInt64
    init(spaceID: UInt64) { self.spaceID = spaceID }
}

private final class FakeNumbersResult: NSObject {
    @objc let numbers: [NSNumber]
    init(numbers: [NSNumber]) { self.numbers = numbers }
}

private final class FakePlistArrayResult: NSObject {
    @objc let propertyListArray: [[String: Any]]
    init(propertyListArray: [[String: Any]]) {
        self.propertyListArray = propertyListArray
    }
}

/// A SYNCHRONOUS operation: `perform…` returns a result object.
private final class FakeGetCurrentSpace: NSObject {
    @objc(initWithDisplayIdentifier:)
    init(displayIdentifier: String) {
        Seen.displayIdentifier = displayIdentifier
    }

    @objc func performWithWMBridgeDelegate() -> AnyObject? {
        Seen.performed += 1
        return FakeSpaceIDResult(spaceID: 42)
    }
}

/// A synchronous operation whose delegate is ABSENT — the
/// AppKit-not-loaded shape: the class resolves, the operation
/// initialises, and `perform…` answers nil.
private final class FakeDeafGetCurrentSpace: NSObject {
    @objc(initWithDisplayIdentifier:)
    init(displayIdentifier: String) {}

    @objc func performWithWMBridgeDelegate() -> AnyObject? { nil }
}

private final class FakeCopyManagedDisplaySpaces: NSObject {
    @objc override init() {}

    @objc func performWithWMBridgeDelegate() -> AnyObject? {
        FakePlistArrayResult(propertyListArray: [
            ["Display Identifier": "Main", "Spaces": []]
        ])
    }
}

private final class FakeCopySpacesForWindows: NSObject {
    @objc(initWithOptions:windows:)
    init(options: UInt32, windows: [NSNumber]) {
        Seen.windows = windows
        Seen.spaceID = UInt64(options)
    }

    @objc func performWithWMBridgeDelegate() -> AnyObject? {
        FakeNumbersResult(numbers: [1, 5])
    }
}

/// An ASYNCHRONOUS operation: `perform…` returns void, and the
/// C scalar in its initialiser is the reason the plumbing goes
/// through a typed `objc_msgSend`.
private final class FakeMoveWindows: NSObject {
    @objc(initWithWindows:spaceID:)
    init(windows: [NSNumber], spaceID: UInt64) {
        Seen.windows = windows
        Seen.spaceID = spaceID
    }

    @objc func performWithWMBridgeDelegate() {
        Seen.performed += 1
    }
}

// MARK: - Suite

/// The wrapper's contract, proven through its resolver seam and
/// never against the machine (`tests.md`): an absent class
/// degrades to nil/false without a trap, a synchronous result is
/// read by key, an asynchronous dispatch passes its C scalars
/// through, and a resolving class whose delegate is deaf reads
/// as unavailable.
@Suite("WMBridge plumbing", .serialized)
struct WMBridgeTests {
    private func resolving(
        _ classes: [String: AnyClass],
        _ body: () -> Void
    ) {
        Seen.reset()
        WMBridge.classResolverOverride = { name in
            Seen.requested.append(name)
            return classes[name]
        }
        defer { WMBridge.classResolverOverride = nil }
        body()
    }

    @Test("Absent classes: every entry point degrades, none traps")
    func absentCapabilityDegrades() {
        resolving([:]) {
            #expect(WMBridge.isAvailable == false)
            #expect(WMBridge.managedDisplays() == nil)
            #expect(WMBridge.managedDisplaySpaces() == nil)
            #expect(
                WMBridge.currentSpace(displayIdentifier: "M") == nil
            )
            #expect(WMBridge.name(of: 1) == nil)
            #expect(WMBridge.values(of: 1) == nil)
            #expect(WMBridge.spaces(for: [WindowID(1)]) == nil)
            #expect(
                WMBridge.setCurrentSpace(1, displayIdentifier: "M")
                    == false
            )
            #expect(WMBridge.createSpace() == nil)
            #expect(WMBridge.destroySpace(1) == false)
            #expect(WMBridge.setName("x", of: 1) == false)
            #expect(WMBridge.setValues(["k": 1], of: 1) == false)
            #expect(
                WMBridge.moveWindows([WindowID(1)], to: 1) == false
            )
            #expect(
                WMBridge.addWindows([WindowID(1)], to: [1]) == false
            )
            #expect(
                WMBridge.removeWindows([WindowID(1)], from: [1])
                    == false
            )
        }
    }

    @Test("Lookups ask for the short name; the prefix joins later")
    func lookupsUseShortNames() {
        resolving([:]) {
            _ = WMBridge.createSpace()
            #expect(Seen.requested == ["SpaceCreateOperation"])
        }
    }

    @Test("A synchronous result is read by its declared key")
    func synchronousResultIsReadByKey() {
        resolving([
            "ManagedDisplayGetCurrentSpaceOperation":
                FakeGetCurrentSpace.self
        ]) {
            let space = WMBridge.currentSpace(
                displayIdentifier: "D-1"
            )
            #expect(space == 42)
            #expect(Seen.displayIdentifier == "D-1")
            #expect(Seen.performed == 1)
        }
    }

    @Test("An asynchronous dispatch passes objects and scalars")
    func asynchronousDispatchPassesArguments() {
        resolving([
            "MoveWindowsToManagedSpaceOperation": FakeMoveWindows.self
        ]) {
            let moved = WMBridge.moveWindows(
                [WindowID(7), WindowID(9)],
                to: 3
            )
            #expect(moved)
            #expect(Seen.windows == [7, 9])
            #expect(Seen.spaceID == 3)
            #expect(Seen.performed == 1)
        }
    }

    @Test("Membership query maps numbers to space ids")
    func membershipQueryMapsNumbers() {
        resolving([
            "CopySpacesForWindowsOperation":
                FakeCopySpacesForWindows.self
        ]) {
            let spaces = WMBridge.spaces(
                for: [WindowID(4)],
                options: 7
            )
            #expect(spaces == [1, 5])
            #expect(Seen.windows == [4])
            #expect(Seen.spaceID == 7)
        }
    }

    @Test("Availability needs a synchronous read to ANSWER")
    func availabilityNeedsAnAnsweringDelegate() {
        resolving([
            "CopyManagedDisplaySpacesOperation":
                FakeCopyManagedDisplaySpaces.self
        ]) {
            #expect(WMBridge.isAvailable)
            #expect(WMBridge.managedDisplays() == ["Main"])
        }
        resolving([
            "ManagedDisplayGetCurrentSpaceOperation":
                FakeDeafGetCurrentSpace.self
        ]) {
            #expect(
                WMBridge.currentSpace(displayIdentifier: "M") == nil
            )
            #expect(WMBridge.isAvailable == false)
        }
    }
}
