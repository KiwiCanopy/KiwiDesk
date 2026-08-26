import Foundation
import Testing

/// The CLI renders the listing; it never re-derives it (#1033).
///
/// `kiwidesk help <name>` is answered locally, from the binary's
/// own `APIReference`, so it works while the app is not running.
/// That ruling only holds while the local answer and the socket
/// answer are the SAME answer — the moment the CLI walks
/// `APIReference.commands` or `namespaces` itself to build a
/// listing, there are two implementations of "what commands
/// exist" in one binary, and the drift #1033 removed is back
/// inside the fix.
///
/// A unit test cannot see this: both implementations would
/// return plausible listings, and only a reader comparing them
/// would notice. So the seam is scanned instead.
@Suite("CLI help seam")
struct CLIHelpSeamTests {
    static let cliDirectory = "Sources/KiwiDesk"

    /// The CLI files allowed to name the reference at all, and
    /// what each may say. Anything else in the CLI tree building
    /// a listing is the failure this guard exists for.
    static let helpFiles = ["CLIHelp.swift", "CLIHelpText.swift"]

    /// Re-derivation: the name tables `APIReference` exposes for
    /// Lua registration and the typo guard. The CLI has no
    /// business reading them — `helpResponse` and `groups` are
    /// its two doors.
    static let nameTables = [
        "APIReference.commands",
        "APIReference.namespaces",
        "APIReference.luaOnly",
        "APIReference.allCommands",
        "APIReference.dispatchable",
    ]

    static func source(_ name: String) throws -> String {
        let root = SourceScan.repoRoot(from: #filePath)
        return try SourceScan.strippedSource(
            at:
                root
                .appendingPathComponent(cliDirectory)
                .appendingPathComponent(name)
        )
    }

    @Test("the help verbs route to CLIHelp, not the socket")
    func routing() throws {
        let main = try Self.source("CLIMain.swift")
        let oneList =
            "runCLI must recognise the help verbs through "
            + "CLIHelp's own list, not a second one"
        #expect(main.contains("CLIHelp.verbs.contains"), "\(oneList)")
        #expect(
            main.contains("CLIHelp.run(arguments)"),
            "the help verbs must reach CLIHelp"
        )
        let usage =
            "the usage block is printed by CLIHelp, which is "
            + "the one place that knows a topic was given"
        #expect(!main.contains("print(cliUsage)"), "\(usage)")
    }

    @Test("the CLI asks Core for the listing, never rebuilds it")
    func noSecondListing() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let directory = root.appendingPathComponent(
            Self.cliDirectory
        )
        let files = try SourceScan.swiftSources(under: directory)
        #expect(
            !files.isEmpty,
            "the CLI tree moved; this guard scans nothing"
        )
        for file in files {
            let text = try SourceScan.strippedSource(at: file)
            for table in Self.nameTables {
                let message =
                    "\(file.lastPathComponent) reads \(table); "
                    + "the CLI's doors are "
                    + "APIReference.helpResponse and "
                    + "APIReference.groups"
                #expect(!text.contains(table), "\(message)")
            }
        }
    }

    @Test("CLIHelp answers from helpResponse")
    func oneImplementation() throws {
        let help = try Self.source("CLIHelp.swift")
        #expect(
            help.contains("APIReference.helpResponse(for: topic)"),
            "the payload must be the dispatcher's own answer"
        )
    }

    @Test("the renderer is pure over entries")
    func rendererTakesStructure() throws {
        // The text half must not reach for the reference itself
        // either: it is handed groups and entries, so a test can
        // render a fixture without the real surface.
        let text = try Self.source("CLIHelpText.swift")
        #expect(
            !text.contains("APIReference.groups"),
            "CLIHelpText renders what it is given"
        )
        #expect(
            !text.contains("helpResponse"),
            "CLIHelpText renders; CLIHelp fetches"
        )
    }
}
