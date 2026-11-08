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
        // The order the presets' "Main screen" / "Screen 2" number.
        let place = PositionalDisplays.ordered(
            displays,
            mainID: PositionalDisplays.liveMainID
        ).firstIndex { $0.id == display }
        return ScreenLabel(name: named.name, twinPlace: place)
    }

    /// The screen each Desktop number a command takes lands on in
    /// `snapshot` (#2792); empty with one screen connected.
    public func desktopLandings(
        in snapshot: DesktopSnapshot
    ) -> [Int: ScreenLabel] {
        var out: [Int: ScreenLabel] = [:]
        for space in snapshot.spaces where space.isUser {
            guard let number = snapshot.number(of: space.id),
                let display = display(forUUID: space.displayUUID),
                let screen = screenLabel(of: display)
            else { continue }
            out[number] = screen
        }
        return out
    }
}
