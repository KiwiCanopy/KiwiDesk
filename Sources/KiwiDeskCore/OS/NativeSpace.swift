import Foundation

/// One native macOS Space, read from the managed-display plist.
public struct NativeSpace: Sendable, Equatable {
    public let id: SkyLight.SpaceID
    public let displayUUID: String
    public let isCurrent: Bool
    /// False for fullscreen-app and system spaces, which
    /// Mission Control does not count as desktops.
    public let isUser: Bool
    /// KiwiDesk's stamp on this Desktop, if it carries one
    /// (#1147). Read from the SAME plist the topology comes
    /// from — the bridge writes it, nothing reads it back
    /// through the bridge — so every snapshot carries identities
    /// at no extra cost.
    public let identity: DesktopIdentity?
    /// The windows a full-screen Space shows, from the same plist;
    /// empty for a Desktop (#2949).
    public let fullScreenWindows: [WindowID]

    public init(
        id: SkyLight.SpaceID,
        displayUUID: String,
        isCurrent: Bool,
        isUser: Bool = true,
        identity: DesktopIdentity? = nil,
        fullScreenWindows: [WindowID] = []
    ) {
        self.id = id
        self.displayUUID = displayUUID
        self.isCurrent = isCurrent
        self.isUser = isUser
        self.identity = identity
        self.fullScreenWindows = fullScreenWindows
    }
}
