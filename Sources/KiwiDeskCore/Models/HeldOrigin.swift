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
    /// The arrangement it left — it goes home only into that one
    /// (#1230: arrangements never merge by name). Nil where no
    /// profile or Standard was live.
    public let arrangement: Arrangement?

    /// A saved profile or a composed Standard, by name.
    public enum Arrangement: Equatable, Sendable {
        case profile(String)
        case standard(String)
    }

    /// The screen's own name, for the sentence the bar announces.
    public var screenName: String {
        Display.fingerprintParts(screen).name
    }
}
