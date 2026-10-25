import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// `kiwidesk list_commands --kind` (#2610): the flag takes its
/// value as the next argument, is removed before the name is read,
/// and refuses a missing value, an unknown kind or a name beside it.
@Suite("CLI help --kind")
struct CLIHelpKindTests {
    @Test("the flag and its value leave the arguments")
    func takesThePair() throws {
        var rest = ["--kind", "setting", "--json"]
        let kind = try CLIHelp.takeKind(from: &rest).get()
        #expect(kind == .setting)
        #expect(rest == ["--json"])
        var none = ["--json"]
        #expect(try CLIHelp.takeKind(from: &none).get() == nil)
        #expect(none == ["--json"])
    }

    @Test("a missing or unknown value is refused, naming the kinds")
    func refusesABadValue() {
        for arguments in [["--kind"], ["--kind", "verb"]] {
            var rest = arguments
            guard case .failure(let refusal) = CLIHelp.takeKind(from: &rest)
            else {
                Issue.record("\(arguments) was accepted")
                continue
            }
            #expect(refusal.message.contains(APIKind.expectedList))
        }
    }

    @Test("run refuses each bad form with exit 1")
    func runRefuses() {
        for tail in [
            ["--kind"], ["--kind", "verb"], ["--kind", "action", "focus"],
        ] {
            let code = CLIHelp.run(["kiwidesk", "list_commands"] + tail)
            #expect(code == 1, "\(tail)")
        }
    }
}
