import Foundation
import Testing

@testable import KiwiDeskCore

/// Every command the catalogue advertises is one the dispatcher
/// recognises (#1009). `APIReference.dispatchable` is derived
/// from the catalogue, and every other guard on the command
/// surface checks that catalogue against itself — so a verb
/// whose `case` arm was deleted stayed registered into Lua,
/// offered by `help`, suggested by the did-you-mean and
/// classified by `FocusedCommandPolicy`, and answered
/// `unknown command: focus_desktop — did you mean
/// 'focus_desktop'?`. This is the one net pairing the catalogue
/// with `execute`.
///
/// Recognition, not success: most verbs refuse a placeholder
/// argument, which is the arm ANSWERING, so the clause is only
/// that the refusal is not the dispatcher's own.
///
/// The probe passes each verb its record's arguments rather
/// than none, because a bare call cannot reach every arm:
/// `mouse.set_*` reads its Bool and every `_override` its Space
/// BEFORE switching on the field, so a bare call answers the
/// parse whether or not the arm exists. The record is the one
/// place the shape is stated (#1033), so the probe reads it.
///
/// One core, the Desktop bridge pinned ABSENT: `WMBridge`
/// resolves live under test, so `focus_desktop 1` would switch
/// the developer's real Desktop. Pinned absent, every Desktop
/// verb refuses at `canDriveDesktops`, which is its arm
/// answering. The override is process-global and written by
/// `DesktopCommandTests` too; both are synchronous main-actor
/// bodies, so neither can observe the other's window.
@Suite("Catalogued commands reach dispatch (#1009)", .serialized)
@MainActor
struct CommandDispatchReachTests {
    /// The dispatcher's "no arm" refusals, by spelling.
    /// `unknown command:` names the whole verb (an `_override`
    /// arm spells it in full); the setting spellings name the
    /// FIELD the verb ends in. Argument refusals — `unknown
    /// space:`, `unknown mode:` — are not here: they are the arm
    /// answering.
    private static let noArm = [
        "unknown command: ",
        "unknown bar setting: ",
        "unknown space bar setting: ",
        "unknown drag setting: ",
    ]

    /// The one catalogued name `execute` never sees:
    /// `SocketServer` answers `subscribe` itself, ahead of
    /// dispatch, because it binds the CLIENT to an event stream
    /// rather than acting on the core.
    private static let exempt: Set<String> = [
        APIReference.socketOnlyCommand
    ]

    /// Placeholder values in the record's own shape. A choice
    /// takes its first legal value, so the arm behind it is
    /// reached rather than refused at the parse.
    private static func arguments(for name: String) -> [JSONValue] {
        let record = APIReference.entry(named: name)?.record
        return (record?.arguments ?? []).map { argument in
            switch argument.kind {
            case .number, .integer, .desktop: return .number(1)
            case .boolean: return .bool(true)
            case .text: return .string("probe")
            case .color: return .string("#FFFFFF")
            case .space: return .string("1")
            case .choice(let choice):
                return .string(choice.values.first ?? "")
            case .callback, .table: return .null
            }
        }
    }

    /// Whether `response` is the dispatcher saying `name` has no
    /// arm. Anchored on the SUBJECT the refusal names: `help
    /// probe` answers `unknown command: probe`, which is `help`'s
    /// arm working, not `help` missing. A field subject must end
    /// the verb after `_` or `.`, so `thickness` claims
    /// `app_bar.set_thickness` and nothing shorter.
    private func refusesArm(
        _ name: String,
        _ response: CommandResponse
    ) -> Bool {
        guard let error = response.error,
            let spelling = Self.noArm.first(where: error.hasPrefix)
        else { return false }
        let subject =
            error.dropFirst(spelling.count)
            .split(whereSeparator: \.isWhitespace)
            .first.map(String.init) ?? ""
        return name == subject
            || name.hasSuffix("_" + subject)
            || name.hasSuffix("." + subject)
    }

    @Test("every dispatchable command is recognised")
    func recognised() {
        WMBridge.classResolverOverride = { _ in nil }
        defer { WMBridge.classResolverOverride = nil }
        let core = makeTestCore()
        let names = APIReference.dispatchable.filter {
            !Self.exempt.contains($0)
        }
        #expect(!names.isEmpty)
        for name in names {
            let response = core.execute(
                name,
                args: Self.arguments(for: name)
            )
            #expect(
                !refusesArm(name, response),
                Comment(
                    rawValue: "\(name) is catalogued but has no "
                        + "dispatch arm: \(response.error ?? "")"
                )
            )
        }
    }

    /// The exemption stays honest from both sides: the name is
    /// still catalogued (else the row is dead), `execute` still
    /// does NOT recognise it (else the route moved and the row
    /// hides a real arm), and the socket still answers it by
    /// its literal ahead of dispatch.
    @Test("the socket-only exemption names a real route")
    func exemptionIsLive() throws {
        let core = makeTestCore()
        for name in Self.exempt {
            #expect(APIReference.dispatchable.contains(name))
            #expect(refusesArm(name, core.execute(name)))
        }
        var url = URL(fileURLWithPath: #filePath)
        while url.lastPathComponent != "Tests" {
            url.deleteLastPathComponent()
            try #require(url.path != "/")
        }
        url.deleteLastPathComponent()
        let socket = try String(
            contentsOf: url.appendingPathComponent(
                "Sources/KiwiDeskCore/IPC/SocketServer.swift"
            ),
            encoding: .utf8
        )
        let literal = "\"\(APIReference.socketOnlyCommand)\""
        #expect(socket.contains("request.command == \(literal)"))
    }

    /// The predicate can see each refusal spelling it lists —
    /// held here so a spelling that drifts in production reds
    /// this clause rather than silently blinding `recognised`.
    @Test("each no-arm spelling is one the dispatcher still uses")
    func spellingsAreLive() {
        WMBridge.classResolverOverride = { _ in nil }
        defer { WMBridge.classResolverOverride = nil }
        let core = makeTestCore()
        let probes = [
            "no_such_verb",
            "app_bar.set_no_such_field",
            "space_bar.set_no_such_field",
            "drag.set_ghost_no_such_field",
        ]
        var seen: Set<String> = []
        for probe in probes {
            let response = core.execute(probe, args: [.bool(true)])
            #expect(refusesArm(probe, response), Comment(rawValue: probe))
            if let error = response.error,
                let spelling = Self.noArm.first(where: error.hasPrefix)
            {
                seen.insert(spelling)
            }
        }
        #expect(seen == Set(Self.noArm))
    }
}
