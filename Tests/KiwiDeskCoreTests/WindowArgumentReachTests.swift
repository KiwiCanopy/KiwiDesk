import Foundation
import Testing

@testable import KiwiDeskCore

/// A record taking a `.window` argument exempts its verb from the
/// #292 preflight, so the handler must read that argument —
/// through `commandTarget` — or a named call skips the preflight
/// and still acts on the focus (#1518). Forget-proof: every such
/// record in the catalogue is probed with an id no window carries,
/// which only a handler that reads the argument can refuse.
@Suite("Window arguments reach their handler (#1518)", .serialized)
@MainActor
struct WindowArgumentReachTests {
    /// Placeholder values for the arguments ahead of the window.
    private func leading(_ argument: APIArgument) -> JSONValue {
        switch argument.kind {
        case .space: return .string("2")
        case .choice(let choice): return .string(choice.values.first ?? "")
        case .boolean: return .bool(true)
        case .text: return .string("probe")
        default: return .number(1)
        }
    }

    @Test("every window-taking verb refuses an unknown window")
    func unknownRefusedEverywhere() {
        let verbs = APIReference.dispatchable.filter {
            APIReference.windowArgumentIndex($0) != nil
        }
        #expect(!verbs.isEmpty)
        for verb in verbs {
            let core = makeTestCore()
            core.state.apply(
                .windowCreated(
                    ManagedWindow(id: WindowID(1), pid: 1, appName: "A")
                )
            )
            let arguments =
                APIReference.entry(named: verb)?.record.arguments ?? []
            let args = arguments.map { argument in
                argument.kind == .window ? .number(99) : leading(argument)
            }
            let response = core.execute(verb, args: args)
            #expect(response.error == "unknown window: 99", "\(verb)")
        }
    }
}
