import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// `kiwidesk __complete` (#1685 ▸ Ruling 6e): candidates read off
/// the binary's own reference, live names off the app.
@Suite("CLI completer")
struct CLICompleterTests {
    /// A completer whose app answers with `answers`, keyed by the
    /// request's command, and records what it was asked.
    final class FakeApp: @unchecked Sendable {
        var asked: [String] = []
        let answers: [String: JSONValue]
        init(_ answers: [String: JSONValue]) { self.answers = answers }
    }

    static func completer(_ app: FakeApp) -> CLICompleter {
        var completer = CLICompleter()
        completer.live.send = { request in
            app.asked.append(request.command)
            return app.answers[request.command].map(CommandResponse.ok)
        }
        return completer
    }

    static func candidates(
        _ words: [String],
        _ current: String,
        app: FakeApp = FakeApp([:])
    ) -> [String] {
        guard
            case .candidates(let list) = completer(app).answer(
                words: words,
                current: current
            )
        else { return [] }
        return list
    }

    @Test("the first word offers local verbs and every CLI command")
    func firstWord() {
        let all = Self.candidates([], "")
        for verb in ["watch", "completion", "service", "mcp", "help"] {
            #expect(all.contains(verb), "missing \(verb)")
        }
        #expect(all.contains("focus_space"))
        #expect(all.contains("scroll.set_anchor"))
        #expect(all.contains("subscribe"))
        #expect(!all.contains(CLICompleter.verb), "hidden verb offered")
        #expect(!all.contains("--version"), "flags only after `-`")
        #expect(!all.contains("exec"), "a Lua-only verb is offered")
        #expect(Self.candidates([], "-").contains("--version"))
        #expect(Self.candidates([], "load_") == ["load_profile"])
    }

    @Test("an argument offers its record's values")
    func recordValues() {
        #expect(
            Self.candidates(["scroll.set_anchor"], "")
                == ScrollingParams.Anchor.allCases.map(\.rawValue)
        )
        #expect(Self.candidates(["set_mode", "1"], "sc") == ["scrolling"])
        #expect(Self.candidates(["service"], "") == CLIRoute.serviceActions)
        #expect(Self.candidates(["completion"], "") == CLICompleter.shells)
    }

    @Test("subscribe and watch offer the events subscribe's record lists")
    func events() {
        let events = KiwiNotification.allCases.map(\.rawValue)
        #expect(CLICompleter.events == events)
        let subscribe = Self.candidates(["subscribe", "focus_change"], "")
        #expect(!subscribe.contains("focus_change"), "repeats a name")
        #expect(subscribe.contains(CLIEventStream.reconnectFlag))
        let watch = Self.candidates(["watch"], "")
        #expect(watch.contains("space_change"))
        #expect(watch.last == CLIWatch.separator)
        #expect(
            CLICompleter().answer(
                words: ["watch", "space_change", "--"],
                current: ""
            ) == .shellDefault
        )
    }

    @Test("live names come from the app, and only when asked")
    func liveNames() {
        let app = FakeApp([
            "get_state": .object([
                "spaces": .array([
                    .object(["id": .string("1")]),
                    .object(["id": .string("dev")]),
                ]),
                "windows": .array([.object(["id": .number(4711)])]),
            ]),
            "list_profiles": .array([.string("Dual Monitor")]),
            "look.list": .object([
                "looks": .array([.object(["name": .string("Glass")])])
            ]),
        ])
        #expect(
            Self.candidates(["focus_space"], "", app: app) == ["1", "dev"]
        )
        #expect(
            Self.candidates(["load_profile"], "", app: app)
                == ["Dual Monitor"]
        )
        #expect(Self.candidates(["look.apply"], "", app: app) == ["Glass"])
        #expect(app.asked == ["get_state", "list_profiles", "look.list"])
        _ = Self.candidates(["scroll.set_anchor"], "", app: app)
        _ = Self.candidates([], "", app: app)
        #expect(app.asked.count == 3, "a static answer asked the app")
    }

    @Test("an app that does not answer offers nothing")
    func noApp() {
        #expect(Self.candidates(["load_profile"], "").isEmpty)
    }

    @Test("every live text source names a real text argument")
    func textSourcesResolve() {
        for (command, arguments) in CLILiveValues.textSources {
            let entry = APIReference.entry(named: command)
            #expect(entry != nil, "\(command) is not a command")
            for name in arguments.keys {
                let argument = entry?.record.arguments.first {
                    $0.name == name
                }
                #expect(argument?.kind == .text, "\(command) \(name)")
            }
        }
    }

    @Test("each live source's request is a command the CLI can send")
    func liveRequestsExist() {
        let sources: [CLILiveValues.Source] = [
            .spaces, .windows, .profiles, .looks,
        ]
        for source in sources {
            let command = CLILiveValues.request(for: source).command
            #expect(
                CLICompleter.commandNames.contains(command),
                "\(command) is not a CLI command"
            )
        }
    }
}
