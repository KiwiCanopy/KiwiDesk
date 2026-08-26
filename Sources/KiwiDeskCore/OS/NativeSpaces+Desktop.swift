import CoreGraphics
import Foundation

/// One switch's reading of the desktop topology (#888): the
/// active-Desktop authority and every screen's current Space,
/// taken from ONE `allSpaces()` snapshot.
///
/// One value rather than two reads, because the switch handler
/// and the event emit ask the same question — *which screen
/// switched, and to what* — and two readings taken moments apart
/// can disagree (review, 2026-08-18). Whoever handles a switch
/// reads this once and passes it on.
public struct DesktopSnapshot: Sendable {
    /// The Mission Control number of the MAIN screen's current
    /// Desktop, or nil when that Desktop is a fullscreen/system
    /// space, or without SkyLight (callers treat nil as
    /// single-space, as with `activeSpaceNumber()`).
    public let authority: Int?
    /// UUID of the main screen, or nil when the topology cannot
    /// name it (no SkyLight, no display-UUID symbol, or shared
    /// mode's synthetic managed-display identifier).
    public let mainUUID: String?
    /// Each screen's current Space, keyed by its display UUID
    /// (SkyLight's own key name).
    public let currentSpaces: [String: SkyLight.SpaceID]
    /// The spaces the snapshot was read from — so a consumer can
    /// number a Space in the SAME topology the authority was
    /// counted in.
    public let spaces: [NativeSpace]

    /// The Mission Control number of `space` in this snapshot.
    public func number(of space: SkyLight.SpaceID) -> Int? {
        NativeSpaces.number(of: space, in: spaces)
    }

    /// The Desktop carrying Mission Control `number`, or nil
    /// when no user Desktop has it.
    ///
    /// The INVERSE of `number(of:)`, and derived from it rather
    /// than re-deriving the rule: #25's own note asks that bind
    /// targets and move targets agree, and a second copy of
    /// "filter `isUser`, take position n" is what would shift
    /// which Desktop a number means when the numbering changes
    /// (the collector's KV-identity item is queued to change
    /// it). One authority, read both ways.
    public func space(numbered wanted: Int) -> NativeSpace? {
        spaces.first { number(of: $0.id) == wanted }
    }

    /// The Mission Control numbers of the MAIN screen's user
    /// Desktops, ascending — the Desktops a binding can fire on
    /// in this arrangement (#888).
    ///
    /// **Numbers, never positions.** Mission Control counts
    /// across every screen, and a binding keys on that global
    /// number, so a consumer may narrow WHICH Desktops it offers
    /// but must keep each one's number: depending on SkyLight's
    /// screen order the main screen's Desktops can be 3 and 4.
    ///
    /// Every user Desktop when the main screen cannot be named
    /// (no SkyLight, shared mode's synthetic managed-display
    /// identifier) — in shared mode every Desktop IS the main
    /// screen's, so the degenerate case answers exactly as it
    /// did before this existed.
    public var mainDisplayDesktops: [Int] {
        guard let mainUUID,
            spaces.contains(where: { $0.displayUUID == mainUUID })
        else {
            return spaces.filter(\.isUser).indices.map { $0 + 1 }
        }
        return
            spaces
            .filter { $0.displayUUID == mainUUID && $0.isUser }
            .compactMap { number(of: $0.id) }
            .sorted()
    }

    /// The Mission Control numbers of EVERY user Desktop in
    /// this snapshot, ascending — every screen's, not one
    /// screen's.
    ///
    /// The peer of `mainDisplayDesktops`, and the two are not
    /// interchangeable: that one narrows to the screen a
    /// *binding* fires on (#888), while a Desktop VERB acts on
    /// the screen the Desktop lives on, so a consumer offering
    /// the verbs must offer them all — narrowing to the main
    /// screen would put a second screen's Desktops out of reach
    /// of every surface but hand-written Lua. Which of the two
    /// a consumer takes is a statement about what it offers,
    /// which is why both exist rather than one with a flag.
    ///
    /// Numbered through `number(of:)`, so a Desktop reads the
    /// same here, in a binding and in `space(numbered:)` — the
    /// one numbering authority, read a third way.
    public var userDesktops: [Int] {
        spaces
            .filter(\.isUser)
            .compactMap { number(of: $0.id) }
            .sorted()
    }

    /// Whether the space now current on `uuid` is a user desktop
    /// — the #670 verdict, per screen and inside this snapshot,
    /// rather than a second live read. True for an unknown
    /// screen: standing down needs positive evidence of a
    /// fullscreen/system space, never a lookup miss.
    public func currentSpaceIsUser(on uuid: String?) -> Bool {
        guard let uuid, let id = currentSpaces[uuid] else {
            return true
        }
        return NativeSpaces.isUserSpace(id, in: spaces)
    }
}

/// The active-Desktop authority (#888): which Mission Control
/// desktop counts as "the" active one for Desktop→profile
/// bindings and the per-Desktop Space memory.
///
/// The definition: **the MAIN screen's current Desktop**.
/// KiwiDesk resolves one active profile for the whole setup, so
/// one screen has to hold the authority, and the main screen
/// (the one with the menu bar) is it — a secondary screen's
/// swipe never changes this answer. With "Displays have separate
/// Spaces" off, or with a single screen, the main screen's
/// Desktop IS the global one, so the answer degenerates to
/// `activeSpaceNumber()` exactly.
extension NativeSpaces {
    /// UUID of the main screen (the one with the menu bar), or
    /// nil when `CGDisplayCreateUUIDFromDisplayID` is
    /// unavailable.
    ///
    /// The ONE main-screen seam this subsystem reads: the emit's
    /// monitor numbering resolves its main screen from this
    /// answer too, so a fixture pinning it cannot get a switch
    /// attributed to one screen and numbered as another
    /// (review, 2026-08-18).
    public static func mainDisplayUUID() -> String? {
        #if DEBUG
            if let override = mainDisplayUUIDOverride {
                return override
            }
        #endif
        return displayUUID(for: DisplayID(CGMainDisplayID()))
    }

    /// Reads the topology once and answers the authority with it.
    ///
    /// When the main screen cannot be found in that snapshot (no
    /// SkyLight, no display-UUID symbol, or macOS's shared mode,
    /// whose managed display carries a synthetic identifier), the
    /// global `activeSpaceNumber()` answers — the public-fallback
    /// ladder os-private-apis.md requires, and in shared mode the
    /// global number is exactly the main screen's.
    public static func desktopSnapshot() -> DesktopSnapshot {
        let spaces = allSpaces()
        let uuid = mainDisplayUUID()
        let current = [String: SkyLight.SpaceID](
            spaces.filter(\.isCurrent).map {
                ($0.displayUUID, $0.id)
            },
            uniquingKeysWith: { first, _ in first }
        )
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
            currentSpaces: current,
            spaces: spaces
        )
    }

    /// Mission Control number of the active Desktop: the MAIN
    /// screen's current Desktop (#888).
    ///
    /// The convenience read, for a caller that wants the number
    /// and nothing else (a diagnostics dump, a Settings refresh).
    /// A caller HANDLING a switch takes `desktopSnapshot()`
    /// instead, so its later questions are answered from the same
    /// reading.
    public static func activeDesktopNumber() -> Int? {
        #if DEBUG
            if let override = activeDesktopNumberOverride {
                return override
            }
        #endif
        return desktopSnapshot().authority
    }
}
