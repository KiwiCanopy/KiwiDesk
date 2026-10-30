import CoreGraphics
import Foundation

/// The screen a Desktop label names beside its number (#2792).
extension KiwiCore {
    /// `display`'s label, nil while one screen is connected —
    /// a lone screen is never named — or for a screen state does
    /// not know.
    func screenLabel(of display: DisplayID) -> ScreenLabel? {
        let displays = state.workspaces.allDisplays
        guard displays.count > 1,
            let named = displays.first(where: { $0.id == display })
        else { return nil }
        guard displays.filter({ $0.name == named.name }).count > 1 else {
            return ScreenLabel(name: named.name)
        }
        let place = screenPlaces(displays).firstIndex(of: display)
        return ScreenLabel(name: named.name, twinPlace: place)
    }

    /// Each Desktop number a command takes, by where it lands in
    /// `snapshot`; empty with one screen connected.
    public func desktopLandings(
        in snapshot: DesktopSnapshot
    ) -> [Int: DesktopLanding] {
        var out: [Int: DesktopLanding] = [:]
        for space in snapshot.spaces where space.isUser {
            guard let number = snapshot.number(of: space.id),
                let local = snapshot.screenNumber(of: space.id),
                let display = display(forUUID: space.displayUUID),
                let screen = screenLabel(of: display)
            else { continue }
            out[number] = DesktopLanding(screen: screen, number: local)
        }
        return out
    }

    /// The main screen first, then the rest in reading order —
    /// left to right, top to bottom in AppKit's y-up frame.
    private func screenPlaces(_ displays: [Display]) -> [DisplayID] {
        let main = NativeSpaces.mainDisplayUUID().flatMap {
            displaysByUUID()[$0]?.id
        }
        let rest = displays.filter { $0.id != main }.sorted {
            ($0.frame.minX, -$0.frame.minY, $0.id.raw)
                < ($1.frame.minX, -$1.frame.minY, $1.id.raw)
        }
        return (main.map { [$0] } ?? []) + rest.map(\.id)
    }
}
