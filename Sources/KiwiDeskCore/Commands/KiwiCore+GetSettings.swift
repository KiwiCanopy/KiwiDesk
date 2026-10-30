import Foundation

/// `get_settings` (#2782): the live keep document, or the leaf a
/// JSON Pointer names in it — the ids `keep_settings` takes. It
/// diffs nothing, so it never says whether a value is saved; that
/// would make it a reader profiles.md rules.
extension KiwiCore {
    public nonisolated static let getSettingsCommand = "get_settings"

    func getSettings(_ args: [JSONValue]) -> CommandResponse {
        var path: [String] = []
        if let value = args.first, value != .null {
            guard let pointer = value.stringValue,
                let parsed = pointer.isEmpty ? [] : KeepPointer.path(pointer)
            else {
                return .fail("expected a JSON Pointer such as /settings")
            }
            path = parsed
        }
        var document = keepDocument
        if args.count > 1, args[1] != .null {
            guard let raw = args[1].stringValue,
                state.workspaces[SpaceID(raw)] != nil
            else {
                return .fail(
                    "unknown space: \(args[1].stringValue ?? "?")"
                )
            }
            document = KeepPointer.setting(
                tiler.settings.resolved(for: SpaceID(raw)).keepJSON,
                at: [KeepRoot.settings],
                in: document
            )
        }
        guard let leaf = KeepPointer.value(at: path, in: document) else {
            return .fail(
                "no setting at \(KeepPointer.string(path))"
            )
        }
        return .ok(leaf)
    }
}
