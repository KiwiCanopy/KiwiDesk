import Foundation

/// The `look.*` verbs (#1685 ▸ Ruling 6b): list, read, wear, save
/// and delete looks from Lua, the CLI and `kiwidesk mcp`. A wear is
/// live only — `save_profile` or `keep_settings` stores it, through
/// the shared-look doors (Ruling 4) — and a save never overwrites.
/// A wear that must also WRITE takes `writeThroughLiveProfile`, as
/// the tour's paint does, never a grown `wearLook`.
extension KiwiCore {
    func lookCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        switch command {
        case "look.list":
            return .ok(lookList())
        case "look.current":
            return .ok(currentLook())
        case "look.apply":
            guard let name = lookName(args) else { return noName }
            switch libraryLook(named: name) {
            case .success(let look):
                wearLook(look)
                return .ok()
            case .failure(let refusal):
                return refusal.response
            }
        case "look.save":
            return saveLiveLook(args)
        case "look.delete":
            return deleteLook(args)
        default:
            return .fail("unknown command: \(command)")
        }
    }

    /// Every look, bundled first, and how far each is worn.
    private func lookList() -> JSONValue {
        let settings = tiler.settings
        let bundled = bundledLooks.map { ($0, true) }
        let saved = lookLibrary.userLooks().map { ($0, false) }
        let rows: [JSONValue] = (bundled + saved).map { look, isBundled in
            var row: [String: JSONValue] = [
                "name": .string(look.name),
                "bundled": .bool(isBundled),
            ]
            switch look.match(settings) {
            case .applied: row["worn"] = .string("applied")
            case .otherColors: row["worn"] = .string("other_colors")
            case .none: break
            }
            return .object(row)
        }
        return .object(["looks": .array(rows)])
    }

    /// The worn look, the setter of each path, and whose look it
    /// is: a profile that follows the shared look shares it with
    /// every follower.
    private func currentLook() -> JSONValue {
        let body = LookBody(of: tiler.settings)
        let follows = liveWearsSharedLook
        var setters: [String: JSONValue] = [:]
        for path in LookKeys.all + ColorPaletteKeys.all {
            if let command = APIReference.lookSetter(for: path) {
                setters[path] = .string(command)
            }
        }
        let followers =
            follows
            ? followingProfiles().map { JSONValue.string($0.name) }
            : []
        return .object([
            "style": .object(body.style),
            "colors": .object(body.colors.mapValues { .string($0) }),
            "setters": .object(setters),
            "profile": profiles.currentName.map { .string($0) } ?? .null,
            "follows_shared_look": .bool(follows),
            "followers": .array(followers),
        ])
    }

    /// A bundled look, else a saved one, by exact name; a library
    /// that cannot be read says so rather than naming no look.
    private func libraryLook(
        named name: String
    ) -> Result<ShelfLook, LookRefusal> {
        if let bundled = bundledLooks.first(where: { $0.name == name }) {
            return .success(bundled)
        }
        guard let saved = try? lookLibrary.libraryLooks() else {
            return .failure(.unreadable)
        }
        guard let look = saved.first(where: { $0.name == name }) else {
            return .failure(.unknown(name))
        }
        return .success(look.admitted)
    }

    /// Paints `look` over the live settings and nothing else: no
    /// file is written, so the change stays unkept (Ruling 4).
    func wearLook(_ look: ShelfLook) {
        let body = LookBody(style: look.style, colors: look.colors)
        tiler.settings = body.painted(over: tiler.settings)
        // An explicit apply (§5): a look can move the shelf's edge.
        retile(pass: .apply)
    }

    private func saveLiveLook(_ args: [JSONValue]) -> CommandResponse {
        guard let name = lookName(args) else { return noName }
        let library = lookLibrary
        if library.isBuiltinName(name) {
            return .fail("a bundled look is named \(name)")
        }
        if library.hasUserLook(name) {
            return .fail(
                "a look named \(name) exists; delete it first"
            )
        }
        do {
            try saveLook(named: name, from: tiler.settings)
            onLookLibraryChanged()
            return .ok()
        } catch {
            return .fail("could not save look: \(error)")
        }
    }

    private func deleteLook(_ args: [JSONValue]) -> CommandResponse {
        guard let name = lookName(args) else { return noName }
        let library = lookLibrary
        if library.isBuiltinName(name) {
            return .fail("a bundled look cannot be deleted")
        }
        do {
            try library.delete(name)
            onLookLibraryChanged()
            return .ok()
        } catch LookStore.StoreError.notFound {
            return LookRefusal.unknown(name).response
        } catch LookStore.StoreError.unreadableLibrary {
            return LookRefusal.unreadable.response
        } catch {
            return .fail("could not delete look: \(error)")
        }
    }

    /// The first argument, trimmed; nil when nothing is left.
    private func lookName(_ args: [JSONValue]) -> String? {
        let name = args.first?.stringValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return name?.isEmpty == false ? name : nil
    }

    private var noName: CommandResponse { .fail("expected a look name") }
}

/// Why a look verb found no look to act on.
enum LookRefusal: Error {
    case unknown(String)
    case unreadable

    var response: CommandResponse {
        switch self {
        case .unknown(let name): .fail("unknown look: \(name)")
        case .unreadable: .fail("the look library cannot be read")
        }
    }
}
