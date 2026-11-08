import Foundation

/// Whether a Space starts with tiling on (#3008): its own value,
/// else its profile's, else the app-wide one.
public struct TilingStart: Sendable, Equatable {
    /// App-wide (`tiling.start_global`).
    public var global = true
    /// The active profile's (`tiling.start`); nil follows
    /// `global`.
    public var profile: Bool?
    /// Per Space (`tiling.start_override`).
    public var spaces: [SpaceID: Bool] = [:]

    public init(
        global: Bool = true,
        profile: Bool? = nil,
        spaces: [SpaceID: Bool] = [:]
    ) {
        self.global = global
        self.profile = profile
        self.spaces = spaces
    }

    /// Whether `space` starts tiled.
    public func startsTiled(_ space: SpaceID) -> Bool {
        spaces[space] ?? profile ?? global
    }
}
