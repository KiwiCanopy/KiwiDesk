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
/// that the refusal is not the dispatcher's own. A gutted arm
/// that returns `.ok()` passes — the behaviour suites own that.
///
/// The probe passes each verb its record's arguments rather
/// than none, because a bare call cannot reach every arm:
/// `mouse.set_*` reads its Bool and every `_override` its Space
/// BEFORE switching on the field, so a bare call answers the
/// parse whether or not the arm exists. The record is the one
/// place the shape is stated (#1033), so the probe reads it —
/// and a dispatcher that parses a SIBLING arm's argument ahead of
/// the name (the `animations.*` toggles' shared Bool guard, until
/// #1009) hides a deleted arm behind that parse, which is why
/// every dispatcher names first.
///
/// Main-actor spend, stated per tests.md: one core and ~260
/// `execute`s, each successful setter forcing a retile, per
/// probing test; the source reads run off the actor.
///
/// Process-global state: `WMBridge.classResolverOverride` is
/// pinned ABSENT, because the bridge resolves live under test
/// and `focus_desktop 1` would switch the developer's real
/// Desktop — pinned, every Desktop verb refuses at
/// `canDriveDesktops`, its arm answering. The Desktop topology
/// is pinned too (`bind_profile_to_desktop` reads a snapshot
/// past that gate). Both are written by the #884/#888 suites as
/// well, whose bodies are synchronous main-actor ones, so no
/// window exists in which one observes the other — and the pin
/// here is held only in the two SYNCHRONOUS bodies: an `await`
/// between `pinMachine()` and `unpin()` would open exactly that
/// window, so the two `async` bodies pin nothing. That this suite is
/// the first to execute EVERY verb, with the pin as two lines
/// and no guard, is the accepted trade — `makeTestCore` cannot
/// hold a process-global static without clobbering the suites
/// that fake it.
@Suite("Catalogued commands reach dispatch (#1009)", .serialized)
@MainActor
struct CommandDispatchReachTests {
    /// The dispatcher's "no arm" refusals, by spelling.
    /// `unknown command:` names the whole verb (an `_override`
    /// arm spells it in full); the setting spellings name the
    /// FIELD the verb ends in. A CENSUS, not a filter:
    /// `spellingsAreCensus` holds it against every `"unknown …:`
    /// literal in Core, with the argument refusals classified in
    /// `argumentRefusals` — a fifth dispatcher spelling its own
    /// refusal would otherwise blind the probe to its whole
    /// namespace with nothing red.
    static let noArm = [
        "unknown command: ",
        "unknown bar setting: ",
        "unknown space bar setting: ",
        "unknown drag setting: ",
    ]

    /// `"unknown …:` literals that refuse an ARGUMENT — the arm
    /// answering — with the reason each is not a no-arm spelling.
    static let argumentRefusals: [String: String] = [
        "unknown space: ": "a Space id no space carries",
        "unknown mode: ": "a layout mode name no case carries",
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

    /// The bridge absent and the #888 topology pinned, for a
    /// body that executes Desktop verbs. Pair with `unpin()`.
    private func pinMachine() {
        WMBridge.classResolverOverride = { _ in nil }
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        NativeSpaces.activeSpaceIDOverride = 10
        pinTwoDisplays()
    }

    private func unpin() {
        WMBridge.classResolverOverride = nil
        resetAuthorityOverrides()
    }

    @Test("every dispatchable command is recognised")
    func recognised() {
        pinMachine()
        defer { unpin() }
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
    /// hides a real arm), and the socket still answers it ahead
    /// of dispatch — by the literal or by the constant that owns
    /// the spelling, either being the route.
    @Test("the socket-only exemption names a real route")
    func exemptionIsLive() async throws {
        let core = makeTestCore()
        for name in Self.exempt {
            #expect(APIReference.dispatchable.contains(name))
            #expect(refusesArm(name, core.execute(name)))
        }
        let socket = try await Self.source(
            "Sources/KiwiDeskCore/IPC/SocketServer.swift"
        )
        let literal = "\"\(APIReference.socketOnlyCommand)\""
        #expect(
            socket.contains("request.command == \(literal)")
                || socket.contains(
                    "request.command == APIReference.socketOnlyCommand"
                )
        )
    }

    /// `noArm` is exactly the no-arm half of every `"unknown
    /// <words>: ` refusal Core spells, the other half classified
    /// above with its reason. A new spelling of that grammar reds
    /// here until it is filed. The grammar is the census's
    /// bound: a refusal spelled outside it (`no such setting:`,
    /// a concatenated string) is unseen here and blinds
    /// `recognised` to its namespace — core-boundaries.md makes
    /// the spelling a convention for that reason.
    @Test("the no-arm spellings are a census of Core's refusals")
    func spellingsAreCensus() async throws {
        let literals = try await Self.unknownLiterals()
        #expect(literals.count >= 4)
        let classified = Set(Self.noArm)
            .union(Self.argumentRefusals.keys)
        #expect(
            literals == classified,
            Comment(
                rawValue: "unclassified: "
                    + "\(literals.subtracting(classified).sorted())"
                    + "; classified but unspelled: "
                    + "\(classified.subtracting(literals).sorted())"
            )
        )
        #expect(
            Set(Self.noArm).isDisjoint(
                with: Self.argumentRefusals.keys
            )
        )
    }

    /// The predicate can see each spelling it lists, live — a
    /// probe per namespace that answers with it.
    @Test("each no-arm spelling is one the dispatcher still uses")
    func spellingsAreLive() {
        pinMachine()
        defer { unpin() }
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

    // MARK: - Source reads, off the actor

    private nonisolated static func repoRoot() throws -> URL {
        var url = URL(fileURLWithPath: #filePath)
        while url.lastPathComponent != "Tests" {
            url.deleteLastPathComponent()
            try #require(url.path != "/")
        }
        url.deleteLastPathComponent()
        return url
    }

    /// `async` and nonisolated so the read runs off the main
    /// actor rather than inside this suite's spend.
    private nonisolated static func source(
        _ path: String
    ) async throws -> String {
        try String(
            contentsOf: repoRoot().appendingPathComponent(path),
            encoding: .utf8
        )
    }

    /// Every `"unknown <words>: ` literal under Core, as the
    /// prefix the predicate matches on.
    private nonisolated static func unknownLiterals() async throws
        -> Set<String>
    {
        let root = try repoRoot().appendingPathComponent(
            "Sources/KiwiDeskCore"
        )
        guard
            let files = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: nil
            ),
            let regex = try? NSRegularExpression(
                pattern: #""(unknown [a-z ]+: )"#
            )
        else { return [] }
        var found: Set<String> = []
        let swift = files.allObjects.compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
        for file in swift {
            let text = try String(contentsOf: file, encoding: .utf8)
            let whole = NSRange(text.startIndex..., in: text)
            for match in regex.matches(in: text, range: whole) {
                if let range = Range(match.range(at: 1), in: text) {
                    found.insert(String(text[range]))
                }
            }
        }
        return found
    }
}
