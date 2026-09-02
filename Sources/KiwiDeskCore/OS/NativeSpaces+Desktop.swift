import CoreGraphics
import Foundation

/// Single snapshot of desktop topology across displays
/// (#888, review 2026-08-18).
public struct DesktopSnapshot: Sendable {
    /// Mission Control number of main screen's desktop (nil if fullscreen).
    public let authority: Int?
    /// UUID of the main screen.
    public let mainUUID: String?
    /// The main screen's current native Space — the id `authority`
    /// is numbered from, with the same global fallback where the
    /// topology cannot name the main screen (#1207).
    public let mainCurrentSpace: SkyLight.SpaceID?
    /// Each screen's current Space ID keyed by display UUID.
    public let currentSpaces: [String: SkyLight.SpaceID]
    /// Raw native spaces in this snapshot.
    public let spaces: [NativeSpace]

    /// Mission Control number of `space` in this snapshot.
    public func number(of space: SkyLight.SpaceID) -> Int? {
        NativeSpaces.number(of: space, in: spaces)
    }

    /// Returns Desktop carrying Mission Control `wanted` number (#25).
    public func space(numbered wanted: Int) -> NativeSpace? {
        spaces.first { number(of: $0.id) == wanted }
    }

    /// Mission Control numbers of MAIN screen's user Desktops (#888).
    public var mainDisplayDesktops: [Int] {
        guard let mainUUID,
            spaces.contains(where: { $0.displayUUID == mainUUID })
        else {
            return userDesktops
        }
        return
            spaces
            .filter { $0.displayUUID == mainUUID && $0.isUser }
            .compactMap { number(of: $0.id) }
            .sorted()
    }

    /// Mission Control numbers of all user Desktops in snapshot (#888).
    public var userDesktops: [Int] {
        spaces
            .filter(\.isUser)
            .compactMap { number(of: $0.id) }
            .sorted()
    }

    /// True if the current space on the display is a user space
    /// (#670). True for an unknown screen: standing down needs
    /// positive evidence of a fullscreen/system space, never a
    /// lookup miss.
    public func currentSpaceIsUser(on uuid: String?) -> Bool {
        guard let uuid, let id = currentSpaces[uuid] else {
            return true
        }
        return NativeSpaces.isUserSpace(id, in: spaces)
    }
}

/// Active-desktop authority and queries for Desktop bindings (#888).
extension NativeSpaces {
    /// UUID of the main display (with menu bar) (review 2026-08-18).
    public static func mainDisplayUUID() -> String? {
        #if DEBUG
            if let override = mainDisplayUUIDOverride {
                return override
            }
        #endif
        return displayUUID(for: DisplayID(CGMainDisplayID()))
    }

    /// Captures topology snapshot determining authority (#888).
    public static func desktopSnapshot() -> DesktopSnapshot {
        let spaces = allSpaces()
        let uuid = mainDisplayUUID()
        let current = [String: SkyLight.SpaceID](
            spaces.filter(\.isCurrent).map {
                ($0.displayUUID, $0.id)
            },
            uniquingKeysWith: { first, _ in first }
        )
        let mainCurrent =
            uuid.flatMap { current[$0] } ?? activeSpaceID()
        let authority: Int? = {
            #if DEBUG
                if let override = activeDesktopNumberOverride {
                    return override
                }
            #endif
            guard let uuid, let id = current[uuid] else {
                return activeSpaceNumber()
            }
            return number(of: id, in: spaces)
        }()
        return DesktopSnapshot(
            authority: authority,
            mainUUID: uuid,
            mainCurrentSpace: mainCurrent,
            currentSpaces: current,
            spaces: spaces
        )
    }

    /// Mission Control number of the active main Desktop (#888).
    public static func activeDesktopNumber() -> Int? {
        #if DEBUG
            if let override = activeDesktopNumberOverride {
                return override
            }
        #endif
        return desktopSnapshot().authority
    }
}
