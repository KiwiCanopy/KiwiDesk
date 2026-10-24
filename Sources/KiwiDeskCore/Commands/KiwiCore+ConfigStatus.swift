import Foundation

/// `get_config_status` (#2490): the Config Issues and the sync
/// status as structure, so a CLI or MCP caller can check before it
/// writes and say why a write was refused. Core names each case and
/// its fields, never a sentence (#96).
extension KiwiCore {
    public nonisolated static let configStatusCommand = "get_config_status"

    func configStatusJSON() -> JSONValue {
        .object([
            "issues": .array(configIssues.map(Self.issueJSON)),
            "sync": syncStatusJSON(),
        ])
    }

    static func issueJSON(_ issue: ConfigIssue) -> JSONValue {
        var fields = kindFields(issue.kind)
        fields["source"] = .string(issue.source)
        if let profile = issue.profileName {
            fields["profile"] = .string(profile)
        }
        return .object(fields)
    }

    private static func kindFields(
        _ kind: ConfigIssue.Kind
    ) -> [String: JSONValue] {
        switch kind {
        case .profileBroken(let cause):
            return [
                "kind": .string("profile_broken"),
                "cause": .string(causeName(cause)),
            ]
        case .luaVMUnavailable:
            return ["kind": .string("lua_vm_unavailable")]
        case .luaError(let message):
            return [
                "kind": .string("lua_error"),
                "message": .string(message),
            ]
        case .guiConfigUnreadable:
            return ["kind": .string("gui_config_unreadable")]
        case .newerFormat:
            return ["kind": .string("newer_format")]
        case .unknownCall(let name, let suggestion):
            return [
                "kind": .string("unknown_call"),
                "name": .string(name),
                "suggestion": suggestion.map(JSONValue.string) ?? .null,
            ]
        case .retiredCall(let name, let replacement):
            return [
                "kind": .string("retired_call"),
                "name": .string(name),
                "replacement": replacement.map(JSONValue.string) ?? .null,
            ]
        case .missingFontFamily(let name):
            return [
                "kind": .string("missing_font_family"),
                "name": .string(name),
            ]
        case .unknownShortcutSymbol(let layer, let chord, let symbol):
            return [
                "kind": .string("unknown_shortcut_symbol"),
                "layer": .string(layer),
                "chord": .string(chord),
                "symbol": .string(symbol),
            ]
        case .deadShortcut(let layer, let chord, let reason):
            var fields: [String: JSONValue] = [
                "kind": .string("dead_shortcut"),
                "layer": .string(layer),
                "chord": .string(chord),
            ]
            switch reason {
            case .invalidChord:
                fields["reason"] = .string("invalid_chord")
            case .luaError(let message):
                fields["reason"] = .string("lua_error")
                fields["message"] = .string(message)
            }
            return fields
        }
    }

    private static func causeName(_ cause: ProfileBrokenCause) -> String {
        switch cause {
        case .malformedJSON: return "malformed_json"
        case .unexpectedShape: return "unexpected_shape"
        case .unreadable: return "unreadable"
        case .newerFormat: return "newer_format"
        }
    }

    private func syncStatusJSON() -> JSONValue {
        var fields: [String: JSONValue] = [
            "folder": sync.folder.map { .string($0.path) } ?? .null
        ]
        switch sync.status {
        case .off: fields["status"] = .string("off")
        case .upToDate: fields["status"] = .string("up_to_date")
        case .folderUnavailable:
            fields["status"] = .string("folder_unavailable")
        case .changedOnBoth: fields["status"] = .string("changed_on_both")
        case .conflictCopy(let path):
            fields["status"] = .string("conflict_copy")
            fields["path"] = .string(path)
        case .newerOnAnotherMac(let newer):
            fields["status"] = .string("newer_on_another_mac")
            fields["file"] = .string(newer.fileName)
        case .newerHere(let newer):
            fields["status"] = .string("newer_here")
            fields["file"] = .string(newer.fileName)
        }
        return .object(fields)
    }
}
