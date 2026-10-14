import Foundation

/// What a socket request changed in the live settings, when it
/// asks (`report_changes`, #1685): the leaves it touched and those
/// it was asked to judge (`keep_watch`), each with where it would
/// be kept, its live value and whether that is stored. Core names;
/// the caller narrates (#96).
public struct ChangeReport: Codable, Sendable, Equatable {
    /// The saved profile that is live, if any.
    public var profile: String?
    /// The leaves the request changed, in id order.
    public var touched: [TouchedLeaf]
    /// The leaves the request asked about (`keep_watch`), judged
    /// after it ran, in id order.
    public var watched: [TouchedLeaf]

    public init(
        profile: String?,
        touched: [TouchedLeaf] = [],
        watched: [TouchedLeaf] = []
    ) {
        self.profile = profile
        self.touched = touched
        self.watched = watched
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
    /// Whether the live value is the one its owner stores — kept,
    /// by a keep, a Save or a value set back. False for a leaf no
    /// keep can write.
    public var stored: Bool
    /// The live value when judged; nil where the leaf is absent.
    public var value: JSONValue?

    public init(
        id: String,
        owner: KeepOwner,
        notKeepable: NotKeepable?,
        stored: Bool = false,
        value: JSONValue? = nil
    ) {
        self.id = id
        self.owner = owner
        self.notKeepable = notKeepable
        self.stored = stored
        self.value = value
    }

    /// This leaf as the wire carries it.
    public var json: JSONValue {
        guard let data = try? JSONEncoder().encode(self),
            let value = try? JSONDecoder().decode(JSONValue.self, from: data)
        else { return .object(["id": .string(id)]) }
        return value
    }

    enum CodingKeys: String, CodingKey {
        case id, owner, stored, value
        case notKeepable = "not_keepable"
    }
}

/// Where a kept leaf lands.
public enum KeepOwner: String, Codable, Sendable, CaseIterable {
    /// The live profile's file.
    case profile
    /// `gui.json`'s shared look, worn by every following profile.
    case sharedLook = "shared_look"
    /// `gui.json`'s shared app rules, which every profile without
    /// its own rule for that app follows (#1685 ▸ Ruling 6c).
    case sharedRules = "shared_rules"
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
    /// The write did not land: the profile's file, or `gui.json`
    /// for the shared look, was not written.
    case notWritten = "not_written"
    /// The leaf cannot be laid over the stored profile — alone, or
    /// with the leaves kept beside it — so nothing was written.
    case conflicting
    /// Not a leaf of the keep document.
    case unknown

    /// Whether a later state can make the leaf keepable — the
    /// Space added to the profile, the file writable again, the
    /// leaf kept alone — so a caller holding it asks again.
    public var isLiftable: Bool {
        switch self {
        case .temporarySpace, .notWritten, .conflicting: return true
        case .luaOwned, .noProfile, .appWide, .unknown: return false
        }
    }
}

extension CommandRequest {
    /// A request that asks for a `ChangeReport` with its answer,
    /// judging `watch` — the leaf ids a caller holds — as well.
    public static func reporting(
        _ command: String,
        args: [JSONValue]? = nil,
        watch: [String] = []
    ) -> CommandRequest {
        var request = CommandRequest(command: command, args: args)
        request.reportChanges = true
        request.keepWatch = watch.isEmpty ? nil : watch
        return request
    }
}
