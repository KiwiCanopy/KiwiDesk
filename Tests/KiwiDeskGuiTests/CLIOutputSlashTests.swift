import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The CLI prints a path as typed.
@Suite("CLI output slashes")
struct CLIOutputSlashTests {
    @Test("CLI output keeps slashes unescaped")
    func slashesAreKept() {
        for pretty in [true, false] {
            let text = CLIOutput.render(
                .object(["path": .string("/Users/me/kd.json")]),
                pretty: pretty
            )
            #expect(text?.contains("/Users/me/kd.json") == true)
            #expect(text?.contains("\\/") == false)
        }
    }
}
