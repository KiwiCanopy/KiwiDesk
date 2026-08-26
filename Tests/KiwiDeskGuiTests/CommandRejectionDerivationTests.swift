import Foundation
import KiwiDeskCore
import Testing

/// A rejection names the values its own decoder accepts, and it
/// reads them off the enum (#1033).
///
/// The compiler already enforces the derivation wherever a call
/// site uses `CommandResponse.expected(_:)` — it takes the type,
/// so it cannot spell the list wrongly. What it cannot enforce
/// is the NEXT setter, written by hand with a fresh string
/// beside it. That is how the shipped defect happened twice
/// over: both bar setters told the user to send
/// `ring|edge_mark|gap` for years after the case was renamed
/// `outline`, and nothing in the tree disagreed with them.
///
/// So this scans the command tree for a string literal that
/// names two or more cases of a decoder enum — the shape of a
/// hand-typed vocabulary — with the enum vocabularies themselves
/// DERIVED from the API records rather than listed here.
///
/// **Its reach is the enums the records NAME**, which is every
/// enum an argument is declared as — an enum a decoder accepts
/// while its record records `.text` is invisible here, because
/// the vocabulary it would match never enters the net. That is
/// the stated limitation, not a claim of completeness: it is
/// how `animations.set_size_policy` hand-typed its two spellings
/// unseen until review, and why the fix was to give that enum
/// raw values so the record could name it.
@Suite("command rejection derivation")
struct CommandRejectionDerivationTests {
    static let commandTree = "Sources/KiwiDeskCore/Commands"

    /// Every enum vocabulary the API records currently name.
    static var vocabularies: [(type: String, values: Set<String>)] {
        var seen: [String: Set<String>] = [:]
        for entry in APIReference.entries {
            for argument in entry.record.arguments {
                guard case .choice(let choice) = argument.kind
                else { continue }
                seen[choice.type] = Set(choice.values)
            }
        }
        return seen.map { ($0.key, $0.value) }.sorted {
            $0.0 < $1.0
        }
    }

    /// Literals that name several values for a reason that is
    /// not a rejection message, or where no enum exists to
    /// derive from. Each entry says which.
    static let allowed: [String: String] = [
        // No enum behind either vocabulary: `resize` compares
        // two bare strings, and the track sequence maps
        // prev/next to a delta. Nothing to read `allCases` off.
        "expected axis (x|y) and delta": "no enum",
        "expected prev|next": "no enum",
    ]

    @Test("the vocabularies are non-empty")
    func netHasInput() {
        // A fail-open scan is worse than none: if the records
        // ever stop naming a choice type, every literal below
        // passes for the wrong reason.
        let found = Self.vocabularies
        let message =
            "only \(found.count) enum vocabularies reached the "
            + "scan; it is not looking at anything"
        #expect(found.count >= 8, "\(message)")
        // Non-empty, not "at least two": `QuitLayoutStyle` has
        // exactly one case today and is a real choice — it is
        // the strategy seam a second style lands in.
        #expect(found.allSatisfy { !$0.values.isEmpty })
    }

    @Test("no command spells a decoder's vocabulary by hand")
    func noHandTypedVocabulary() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let directory = root.appendingPathComponent(
            Self.commandTree
        )
        let files = try SourceScan.swiftSources(under: directory)
        #expect(!files.isEmpty, "the command tree moved")
        let vocabularies = Self.vocabularies
        for file in files
        where !file.path.contains("/Commands/Reference/") {
            let text = try SourceScan.strippedSource(at: file)
            for literal in Self.stringLiterals(in: text)
            where Self.isRejection(literal)
                && Self.allowed[literal] == nil
            {
                for vocabulary in vocabularies {
                    let named = vocabulary.values.filter {
                        literal.contains($0)
                    }
                    let message =
                        "\(file.lastPathComponent): the literal "
                        + "\"\(literal)\" names \(named.sorted()) "
                        + "— \(vocabulary.type)'s own cases. Use "
                        + "CommandResponse.expected(\(vocabulary.type).self)"
                    #expect(named.count < 2, "\(message)")
                }
            }
        }
    }

    /// Whether a literal is shaped like a rejection message.
    ///
    /// Two spellings, and the narrowing is load-bearing rather
    /// than tidiness: without it the scan reads ordinary prose,
    /// and it flagged an API record's own summary — "columns
    /// scroll left/right" names two `AppBarEdge` cases while
    /// being nothing of the kind. Rejections in this tree open
    /// with "expected"; the pipe catches one phrased otherwise,
    /// a pipe between two words being the tell of a hand-typed
    /// list. A rejection that does neither is review's, and
    /// `CommandResponse.expected(_:)` is what makes writing one
    /// unnecessary.
    static func isRejection(_ literal: String) -> Bool {
        literal.hasPrefix("expected") || literal.contains("|")
    }

    /// Single-line string literals, interpolation segments
    /// dropped. Good enough for a rejection message, which is
    /// what this looks for.
    static func stringLiterals(in text: String) -> [String] {
        var literals: [String] = []
        var current = ""
        var inside = false
        var escaped = false
        for character in text {
            if escaped {
                current.append(character)
                escaped = false
                continue
            }
            if character == "\\" && inside {
                escaped = true
                continue
            }
            if character == "\"" {
                if inside { literals.append(current) }
                current = ""
                inside.toggle()
                continue
            }
            if character == "\n" {
                inside = false
                current = ""
                continue
            }
            if inside { current.append(character) }
        }
        return literals
    }
}
