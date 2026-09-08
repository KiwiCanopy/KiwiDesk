import Foundation

@testable import KiwiDeskCore

/// The Desktop verbs' bridge fakes (the resolver seam, never the
/// machine), split from `DesktopCommandTests.swift` at the §2.1
/// ceiling. Internal, since a file-private twin per suite would
/// be the second copy of the seam's shape; `DesktopCommandTests`
/// aliases them file-privately and is the one reader today.
// MARK: - Bridge fakes (the resolver seam, never the machine)

enum DesktopVerbBridge {
    nonisolated(unsafe) static var switches: [(UInt64, String)] = []
    nonisolated(unsafe) static var moves: [([NSNumber], UInt64)] = []
    nonisolated(unsafe) static var hides: [[NSNumber]] = []
    /// Every dispatched operation in order — the set-then-hide
    /// sequence is the #1023 fix, so the ORDER is an assertion,
    /// not a convenience.
    nonisolated(unsafe) static var events: [String] = []

    static func reset() {
        switches = []
        moves = []
        hides = []
        events = []
    }
}

final class DesktopVerbFakePlistArrayResult: NSObject {
    @objc let propertyListArray: [[String: Any]]
    init(propertyListArray: [[String: Any]]) {
        self.propertyListArray = propertyListArray
    }
}

/// The availability probe, answering — the bridge is present.
final class DesktopVerbFakeCopyManagedDisplaySpaces: NSObject {
    @objc override init() {}
    @objc func performWithWMBridgeDelegate() -> AnyObject? {
        DesktopVerbFakePlistArrayResult(propertyListArray: [["Spaces": []]])
    }
}

/// Captures its arguments on `init` but records the call only
/// when the operation is DISPATCHED — "performed is not applied"
/// cuts both ways, and an assertion over a merely-constructed
/// operation would stay green if a verb dropped its perform.
final class DesktopVerbFakeSetCurrentSpace: NSObject {
    private let space: UInt64
    private let display: String

    @objc(initWithDisplayIdentifier:spaceID:)
    init(displayIdentifier: String, spaceID: UInt64) {
        space = spaceID
        display = displayIdentifier
    }

    @objc func performWithWMBridgeDelegate() {
        DesktopVerbBridge.switches.append((space, display))
        DesktopVerbBridge.events.append("set \(space) \(display)")
    }
}

final class DesktopVerbFakeHideSpaces: NSObject {
    private let spaces: [NSNumber]

    @objc(initWithSpaces:)
    init(spaces: [NSNumber]) {
        self.spaces = spaces
    }

    @objc func performWithWMBridgeDelegate() {
        DesktopVerbBridge.hides.append(spaces)
        DesktopVerbBridge.events.append("hide \(spaces)")
    }
}

final class DesktopVerbFakeMoveWindows: NSObject {
    private let windows: [NSNumber]
    private let space: UInt64

    @objc(initWithWindows:spaceID:)
    init(windows: [NSNumber], spaceID: UInt64) {
        self.windows = windows
        space = spaceID
    }

    @objc func performWithWMBridgeDelegate() {
        DesktopVerbBridge.moves.append((windows, space))
    }
}

let desktopVerbBridgeClasses: [String: AnyClass] = [
    "CopyManagedDisplaySpacesOperation":
        DesktopVerbFakeCopyManagedDisplaySpaces.self,
    "ManagedDisplaySetCurrentSpaceOperation":
        DesktopVerbFakeSetCurrentSpace.self,
    "MoveWindowsToManagedSpaceOperation": DesktopVerbFakeMoveWindows.self,
    "HideSpacesOperation": DesktopVerbFakeHideSpaces.self,
]
