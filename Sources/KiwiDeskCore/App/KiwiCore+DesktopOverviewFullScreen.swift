import Foundation

/// Windows in macOS full screen on KiwiHub's Desktops side (#3486,
/// the #1229 / #3171 ruling): each lists as an icon on its Space's
/// line, its pick-up refused (`.fullScreen`). A tracked one is a
/// live member already; one the switch away from it filed as away
/// is hosted on a full-screen Space no Desktop column reads, so the
/// Desktop its screen shows — or, with that Space in front, the one
/// the live Spaces hold (`heldDesktop(on:)`) — lists it on its
/// remembered Space.
extension KiwiCore {
    /// The screen's away windows up on a full-screen Space, in id
    /// order; with shared Desktops every screen's.
    func fullScreenAway(
        on uuid: String?,
        in snapshot: DesktopSnapshot,
        shared: Bool
    ) -> [AwayWindow] {
        state.awayWindows.values
            .filter { entry in
                guard entry.isUp, awayIsFullScreen(entry, in: snapshot)
                else { return false }
                let host = snapshot.spaces.first {
                    $0.id == entry.nativeSpace
                }
                return shared || host?.displayUUID == uuid
            }
            .sorted { $0.id.raw < $1.id.raw }
    }

    /// Whether no Space of `spaces` will take `entry` back. With
    /// shared Desktops every screen lists the set, so a window filed
    /// in another screen's Space is listed there, never here too.
    func unfiled(
        _ entry: AwayWindow,
        outside spaces: [SpaceID],
        shared: Bool
    ) -> Bool {
        guard let space = state.rememberedSpace(of: entry.id) else {
            return true
        }
        return !spaces.contains(space)
            && !(shared && state.workspaces.display(of: space) != nil)
    }

    /// An away window, refused a pick-up where its host is a
    /// full-screen Space (#3486), as a tracked one is.
    func awayOverviewWindow(
        _ entry: AwayWindow,
        in snapshot: DesktopSnapshot
    ) -> DesktopOverview.Window {
        DesktopOverview.Window(
            id: entry.id,
            pid: entry.pid,
            app: entry.appName,
            title: entry.title,
            block: awayIsFullScreen(entry, in: snapshot) ? .fullScreen : nil
        )
    }

    /// `windows` remembered in Space `id`, in the order given.
    func awayWindows(
        _ windows: [AwayWindow],
        in id: SpaceID,
        _ snapshot: DesktopSnapshot
    ) -> [DesktopOverview.Window] {
        windows.filter { state.rememberedSpace(of: $0.id) == id }
            .map { awayOverviewWindow($0, in: snapshot) }
    }

    /// The closing line of `unfiled`, windows no Space here holds,
    /// if any.
    func unfiledLine(
        _ unfiled: [AwayWindow],
        _ snapshot: DesktopSnapshot
    ) -> [DesktopOverview.SpaceLine] {
        guard !unfiled.isEmpty else { return [] }
        return [
            DesktopOverview.SpaceLine(
                space: nil,
                mode: nil,
                isShown: false,
                marker: nil,
                windows: unfiled.map { awayOverviewWindow($0, in: snapshot) },
                lastFocused: nil
            )
        ]
    }

    /// Whether every screen lists one shared set of Desktops
    /// ("Displays have separate Spaces" off): the reading names one
    /// screen key, and no connected screen carries it.
    func sharedDesktops(in snapshot: DesktopSnapshot) -> Bool {
        snapshot.soleDisplayKey.map { displaysByUUID()[$0] == nil } ?? false
    }
}
