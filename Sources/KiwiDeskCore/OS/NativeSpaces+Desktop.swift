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

    /// The one display id every Desktop sits under, nil where the
    /// Desktops name more than one. With "Displays have separate
    /// Spaces" off it is the shared managed-display id, which no
    /// screen's UUID names; a caller tells the two apart by whether
    /// a screen answers to it.
    public var soleDisplayKey: String? {
        let keys = Set(spaces.map(\.displayUUID))
        return keys.count == 1 ? keys.first : nil
    }

    /// Mission Control number of `space` in this snapshot.
    public func number(of space: SkyLight.SpaceID) -> Int? {
        NativeSpaces.number(of: space, in: spaces)
    }

    /// `space`'s number on its own screen, as that screen's
    /// Mission Control strip labels it (#2792). A label, never a
    /// lookup key: verbs and bindings count with `number(of:)`.
    public func screenNumber(of space: SkyLight.SpaceID) -> Int? {
        NativeSpaces.screenNumber(of: space, in: spaces)
    }

    /// Returns Desktop carrying Mission Control `wanted` number (#25).
    public func space(numbered wanted: Int) -> NativeSpace? {
        spaces.first { number(of: $0.id) == wanted }
    }

    /// The durable key this Desktop's state files under
    /// (#1147): its stamp where it carries one, else its Mission
    /// Control number. Nil for a space that is no Desktop —
    /// a fullscreen or system space keys nothing.
    public func key(of space: SkyLight.SpaceID) -> DesktopKey? {
        NativeSpaces.key(of: space, in: spaces)
    }

    /// Each user Desktop's key by its Mission Control number —
    /// the join a per-Desktop row resolves through (#1147). Here
    /// rather than beside a consumer, so the GUI reads the same
    /// derivation `key(of:)` and the re-key already use.
    public var keysByNumber: [Int: DesktopKey] {
        Dictionary(
            spaces.filter(\.isUser).compactMap { space in
                number(of: space.id).flatMap { n in
                    key(of: space.id).map { (n, $0) }
                }
            },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// Each present user Desktop's number on its own screen
    /// (#2792), under every key it answers to — the label a
    /// per-Desktop row draws, never what it resolves through.
    public var screenNumbersByKey: [DesktopKey: Int] {
        var out: [DesktopKey: Int] = [:]
        for space in spaces where space.isUser {
            guard let n = screenNumber(of: space.id) else { continue }
            for key in keys(of: space.id) { out[key] = n }
        }
        return out
    }

    /// The binding authority as a key (#1147): the Desktop the
    /// MAIN display is showing. `authority` is the same Desktop
    /// as a Mission Control number, which is what a row is
    /// labelled with and never what state is filed under.
    public var mainCurrentKey: DesktopKey? {
        mainCurrentSpace.flatMap { key(of: $0) }
    }

    /// BOTH keys a Desktop can be filed under (#1147): its stamp,
    /// and the Mission Control number it was filed at before the
    /// re-key moved it — most specific first.
    ///
    /// The two coexist for one reading. A Desktop stamped this
    /// instant answers by number until the write is confirmed,
    /// and the records filed against it move at that same call —
    /// so between the boot stamp and the first switch, the plist
    /// says identity while the config still says number. Every
    /// reader of a per-Desktop record asks for both, or it misses
    /// a binding that exists (architect review, 2026-09-04).
    public func keys(of space: SkyLight.SpaceID) -> [DesktopKey] {
        guard let native = spaces.first(where: { $0.id == space }),
            native.isUser
        else { return [] }
        let number = number(of: space).map(DesktopKey.number)
        guard let identity = native.identity else {
            return number.map { [$0] } ?? []
        }
        return [.identity(identity)] + (number.map { [$0] } ?? [])
    }

    /// Every key this topology answers to — the presence half of
    /// `space(for:)`, as DATA a consumer can be handed.
    ///
    /// A consumer asking "is this record dormant" takes this
    /// rather than re-deriving the verdict per key shape at its
    /// own call site: that copy diverged once, and #1230 moves
    /// the rule here without touching a copy in a row builder.
    public var presentKeys: Set<DesktopKey> {
        var out: Set<DesktopKey> = []
        for space in spaces where space.isUser {
            for key in keys(of: space.id) { out.insert(key) }
        }
        return out
    }

    /// The Desktop a key names in THIS topology, or nil while it
    /// is absent — its display unplugged, or the Desktop itself
    /// deleted. Absence is never proof it is gone for good, so a
    /// consumer holds such a record dormant rather than pruning
    /// it (#1147 ▸ the #1230 contract, rule 3).
    public func space(for key: DesktopKey) -> NativeSpace? {
        switch key {
        case .identity(let identity):
            return spaces.first { $0.identity == identity }
        case .number(let wanted):
            return space(numbered: wanted)
        }
    }

    /// The key of the Desktop this display is SHOWING — the
    /// per-display read #1230 keys its Space sets by, written
    /// here so that lane adds no second one. Never the binding
    /// authority, which is the main screen's alone (#888).
    public func currentKey(on uuid: String) -> DesktopKey? {
        currentSpaces[uuid].flatMap { key(of: $0) }
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

    /// Every display in `uuids` shows a user Space.
    public func showsUserSpaces(_ uuids: [String]) -> Bool {
        uuids.allSatisfy { currentSpaceIsUser(on: $0) }
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

    /// `currentSpaceIsUser` for every screen this reading names.
    var currentSpacesAreUser: [String: Bool] {
        Dictionary(
            uniqueKeysWithValues: currentSpaces.keys.map {
                ($0, currentSpaceIsUser(on: $0))
            }
        )
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
