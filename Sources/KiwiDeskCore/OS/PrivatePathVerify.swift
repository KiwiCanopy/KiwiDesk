import CoreGraphics
import Foundation

/// The re-queries a `self_test` read is judged by (#1889): a call
/// that answered is not one that is right, so each verdict holds
/// the private answer against an independent reading.
/// Pure, so a test hands both readings in.
enum PrivatePathVerify {
    /// A connection id: zero is the WindowServer refusing one.
    static func connection(_ id: Int32?) -> PrivatePathVerdict {
        guard let id, id != 0 else {
            return .failed("answered no connection")
        }
        return .works("connection \(id)")
    }

    /// The managed Desktop list, read by the C call.
    static func managedSpaces(
        _ spaces: [NativeSpace]
    ) -> PrivatePathVerdict {
        let displays = Set(spaces.map(\.displayUUID)).count
        guard !spaces.isEmpty else {
            return .failed("answered no Desktops")
        }
        return .works("\(spaces.count) Spaces on \(displays) displays")
    }

    /// The active Space must be one the managed list carries.
    static func activeSpace(
        _ active: SkyLight.SpaceID?,
        in spaces: [NativeSpace]
    ) -> PrivatePathVerdict {
        guard let active else {
            return .failed("answered no active Space")
        }
        guard !spaces.isEmpty else {
            return .inconclusive(
                "Space \(active), but no managed list to check"
            )
        }
        guard spaces.contains(where: { $0.id == active }) else {
            return .failed(
                "Space \(active) is not in the managed list"
            )
        }
        return .works("Space \(active), in the managed list")
    }

    /// Each display's current Space, against the one the managed
    /// list marks current for that display.
    static func currentSpaces(
        _ current: (String) -> SkyLight.SpaceID?,
        in spaces: [NativeSpace]
    ) -> PrivatePathVerdict {
        let marked = spaces.filter(\.isCurrent)
        guard !marked.isEmpty else {
            return .inconclusive("the managed list marks no Space")
        }
        for space in marked {
            let answer = current(space.displayUUID)
            guard answer == space.id else {
                let said = answer.map { "\($0)" } ?? "nothing"
                return .failed(
                    "display \(space.displayUUID) answered \(said), "
                        + "the managed list says \(space.id)"
                )
            }
        }
        return .works("\(marked.count) displays agree")
    }

    /// A SkyLight frame against the public window list's.
    static func bounds(
        _ sky: CGRect?,
        of own: PrivatePathContext.OwnWindow?
    ) -> PrivatePathVerdict {
        guard let own else { return noOwnWindow }
        guard let sky else {
            return .failed("answered no frame for window \(own.id)")
        }
        let tolerance: CGFloat = 1
        let agree =
            abs(sky.minX - own.bounds.minX) <= tolerance
            && abs(sky.minY - own.bounds.minY) <= tolerance
            && abs(sky.width - own.bounds.width) <= tolerance
            && abs(sky.height - own.bounds.height) <= tolerance
        guard agree else {
            return .failed(
                "window \(own.id): \(sky) against the public "
                    + "list's \(own.bounds)"
            )
        }
        return .works("window \(own.id)'s frame matches")
    }

    /// The compositor's per-window Space read for our own window.
    static func hostedSpace(
        _ reading: WindowSpaceReading,
        of own: PrivatePathContext.OwnWindow?
    ) -> PrivatePathVerdict {
        guard let own else { return noOwnWindow }
        switch reading {
        case .hosted(let space):
            return .works("window \(own.id) on Space \(space)")
        case .gone:
            return .inconclusive(
                "window \(own.id) answered no Space"
            )
        case .unavailable:
            return .failed("the read could not be made")
        }
    }

    /// The bridge's Desktop list against the C call's: the same
    /// Space ids, or the bridge is answering something else.
    static func bridgeSpaces(
        _ bridge: [[String: Any]]?,
        against spaces: [NativeSpace]
    ) -> PrivatePathVerdict {
        guard let bridge else { return .failed("answered nil") }
        let mine = Set(NativeSpaces.parse(bridge).map(\.id))
        let theirs = Set(spaces.map(\.id))
        guard !theirs.isEmpty else {
            return .inconclusive(
                "\(mine.count) Spaces; the C list answered none"
            )
        }
        guard mine == theirs else {
            return .failed(
                "\(mine.count) Spaces against the C list's "
                    + "\(theirs.count)"
            )
        }
        return .works("\(mine.count) Spaces, matching the C list")
    }

    /// The bridge's Spaces for our window against the C read's.
    static func bridgeWindowSpaces(
        _ bridge: [SkyLight.SpaceID]?,
        against reading: WindowSpaceReading,
        of own: PrivatePathContext.OwnWindow?
    ) -> PrivatePathVerdict {
        guard let own else { return noOwnWindow }
        guard let bridge else { return .failed("answered nil") }
        guard case .hosted(let space) = reading else {
            return .inconclusive(
                "window \(own.id): no C reading to check against"
            )
        }
        guard bridge.contains(space) else {
            return .failed(
                "window \(own.id): \(bridge) lacks Space \(space)"
            )
        }
        return .works("window \(own.id) on Space \(space)")
    }

    /// Answered at all — for a read nothing independent can check.
    static func answered<T>(
        _ value: T?,
        _ what: String
    ) -> PrivatePathVerdict {
        value == nil ? .failed("answered nil") : .works(what)
    }

    static let noOwnWindow = PrivatePathVerdict.inconclusive(
        "KiwiDesk shows no window to read"
    )
}
