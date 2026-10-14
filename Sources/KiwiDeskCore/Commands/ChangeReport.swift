import Foundation

/// What a socket request changed in the live settings, when it
/// asks (`report_changes`, #1685): the leaves it touched, where
/// each would be kept, and the epoch a load or reload moves. Core
/// names; the caller narrates (#96).
public struct ChangeReport: Codable, Sendable, Equatable {
    /// Moves whenever the live settings are replaced wholesale — a
    /// config load, a profile or layout apply — so a caller holding
    /// unkept leaves learns they are gone.
    public var epoch: Int
    /// The saved profile that is live, if any.
    public var profile: String?
    /// The leaves the request changed, in id order.
    public var touched: [TouchedLeaf]

    public init(
        epoch: Int,
        profile: String?,
        touched: [TouchedLeaf] = []
    ) {
        self.epoch = epoch
        self.profile = profile
        self.touched = touched
    }
}

/// One changed leaf: a JSON Pointer into the keep document
/// (`/settings/…`, `/space_modes/<id>`, `/app_wide/<field>`), the
/// place a keep would write it, and why it cannot be kept, if so.
public struct TouchedLeaf: Codable, Sendable, Equatable {
    public var id: String
    public var owner: KeepOwner
    /// Nil when `keep_settings` can write the leaf.
    public var notKeepable: NotKeepable?

    public init(id: String, owner: KeepOwner, notKeepable: NotKeepable?) {
        self.id = id
        self.owner = owner
        self.notKeepable = notKeepable
    }

    enum CodingKeys: String, CodingKey {
        case id, owner
        case notKeepable = "not_keepable"
    }
}

/// Where a kept leaf lands.
public enum KeepOwner: String, Codable, Sendable, CaseIterable {
    /// The live profile's file.
    case profile
    /// `gui.json`'s shared look, worn by every following profile.
    case sharedLook = "shared_look"
    /// `init.lua`, which no keep writes.
    case initLua = "init_lua"
    /// Nowhere a keep can reach.
    case none
}

/// Why a leaf cannot be kept.
public enum NotKeepable: String, Codable, Sendable, CaseIterable {
    /// `init.lua` owns the config; its next reload restores Lua's
    /// value.
    case luaOwned = "lua_owned"
    /// No saved profile is live (a built-in layout).
    case noProfile = "no_profile"
    /// An app-wide value, kept from Settings ▸ General.
    case appWide = "app_wide"
    /// A Space the live profile does not declare.
    case temporarySpace = "temporary_space"
    /// Not a leaf of the keep document.
    case unknown
}

extension CommandRequest {
    /// A request that asks for a `ChangeReport` with its answer.
    public static func reporting(
        _ command: String,
        args: [JSONValue]? = nil
    ) -> CommandRequest {
        var request = CommandRequest(command: command, args: args)
        request.reportChanges = true
        return request
    }
}
