import Foundation

/// Which macOS Desktop a Space's per-Desktop session state is filed
/// under now — the one resolver the stack flip (#2771) and the
/// session sizes (#2921) share.
extension KiwiCore {
    /// The Desktop a Space's screen shows, for its session state.
    enum ShownDesktop: Equatable {
        /// The Desktop its screen shows — nil with no SkyLight
        /// reading, where a store keeps one Desktop-less entry.
        case shown(SkyLight.SpaceID?)
        /// Its screen shows no user Desktop (full screen), or the
        /// reading names none for its screen.
        case none
    }

    /// The Desktop `space`'s screen shows, from the map the head
    /// of each switch files (`DesktopMemory.shownSpaces`) — never
    /// a WindowServer read. Shared mode's one synthetic key
    /// answers for every screen. An empty map reads as no SkyLight;
    /// a screen the last switch did not file (plugged in since)
    /// answers `.none` until its first switch — accepted residue.
    func shownDesktop(of space: SpaceID) -> ShownDesktop {
        guard !desktopMemory.shownSpaces.isEmpty else { return .shown(nil) }
        let uuid =
            state.workspaces.display(of: space)
            .flatMap { NativeSpaces.displayUUID(for: $0) } ?? ""
        guard let native = shownDesktop(onScreen: uuid) else {
            return .none
        }
        let isUser = NativeSpaces.spaceIsUser(
            on: uuid,
            filed: desktopMemory.shownUserSpaces,
            live: { _ in true }
        )
        return isUser ? .shown(native) : .none
    }
}
