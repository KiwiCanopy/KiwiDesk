import Foundation

/// Where a held Space came from (#1507): its name in the
/// arrangement it left and the screen it lived on.
public struct HeldOrigin: Equatable, Sendable {
    /// The Space's name there — its live id too, unless that name
    /// was taken on the remaining screen and it was renumbered.
    public let name: SpaceID
    /// The fingerprint of the screen it lived on (`name:WxH`).
    public let screen: String
    /// The identifier icon it carried there.
    public let icon: String?

    /// The screen's own name, for the sentence the bar announces.
    public var screenName: String {
        guard let colon = screen.lastIndex(of: ":") else {
            return screen
        }
        return String(screen[..<colon])
    }
}
