import Foundation

/// Why a Desktop move refuses a window on a hidden Desktop (#3171):
/// the one verdict `move_to_desktop` answers through and KiwiHub's
/// Desktops side reads at the press, so the panel names the verb's
/// own reason. Core names it; the GUI narrates it.
public enum AwayMoveRefusal: Sendable, Equatable {
    case pocketed
    case pocketWindow
    case fullScreen
    /// A follow ends with focus on the window, which a minimized or
    /// hidden one cannot take.
    case followHidden
    /// A named Space is a membership write a sticky window refuses.
    case sticky
    /// Its last move's frame has not landed yet.
    case stillLanding
    /// macOS numbers no such Desktop.
    case unreachable
    /// This macOS has no private Desktop bridge (os-private-apis.md).
    case noDesktopBridge

    /// The verb's failure text.
    var message: String {
        switch self {
        case .pocketed: KiwiCore.pocketedMoveRefusal
        case .pocketWindow: KiwiCore.outPocketMoveRefusal
        case .fullScreen: "a full-screen window cannot change Desktop"
        case .followHidden: "Can't follow a minimized or hidden window."
        case .sticky: "a sticky window keeps its Space"
        case .stillLanding: "A window moves again once its last move lands."
        case .unreachable: "no such Desktop"
        case .noDesktopBridge:
            "the Desktop bridge is unavailable on this macOS"
        }
    }
}

extension KiwiCore {
    /// The window-state half of the verdict, ahead of the Space
    /// parse.
    func awayMoveVerdict(
        _ away: AwayWindow,
        to target: DesktopTarget,
        follow: Bool
    ) -> AwayMoveRefusal? {
        switch state.pocketPhase(of: away.id) {
        case .pocketed: return .pocketed
        case .out: return .pocketWindow
        case nil: break
        }
        if isFullScreenHost(away.nativeSpace, in: target.spaces) {
            return .fullScreen
        }
        if follow, !away.isUp { return .followHidden }
        return nil
    }

    /// What `move_to_desktop` naming `window` and a Space would
    /// refuse onto the Desktop `native` now; nil for a window that
    /// is not away, whose route is `move_to_space`.
    public func awayMoveRefusal(
        _ window: WindowID,
        toDesktop native: SkyLight.SpaceID,
        follow: Bool
    ) -> AwayMoveRefusal? {
        guard state.windows[window] == nil,
            state.awayWindows[window] != nil
        else { return nil }
        guard canDriveDesktops else { return .noDesktopBridge }
        let snapshot = desktopMemory.readDesktops()
        guard let number = snapshot.number(of: native),
            let target = Self.desktopTarget(number: number, in: snapshot)
        else { return .unreachable }
        refreshAwayHosts()
        guard let away = state.awayWindows[window] else { return nil }
        if let refusal = awayMoveVerdict(away, to: target, follow: follow) {
            return refusal
        }
        if awayIsSticky(away) { return .sticky }
        if desktopMemory.crossingsInFlight.contains(window) {
            return .stillLanding
        }
        return nil
    }
}
