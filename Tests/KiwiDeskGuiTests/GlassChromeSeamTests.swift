import Foundation
import Testing

/// **This tree draws glass through one modifier** (#1295).
///
/// `glassChrome(in:)` is the SwiftUI home for the Liquid Glass
/// branch, the way `GlassPlate` is the AppKit one. Same platform
/// feature, same `macOS 26` line, different call — so a second
/// `#available` spelled at a call site is how the two halves of
/// one idea come to disagree, and
/// [gui.md](../../.claude/rules/gui.md) writes that as an
/// obligation. Without this suite the obligation had nothing
/// behind it and a second spelling shipped green (ui-designer).
@Suite("SwiftUI glass routing (#1295)")
struct GlassChromeSeamTests {
    /// The file the SwiftUI branch lives in.
    private static let home = "GlassChrome.swift"

    /// The platform's glass spellings. More than the one this
    /// tree uses, deliberately: gui.md's obligation is about a
    /// second `#available` branch, not about one function, so a
    /// surface reaching for a sibling API is the same violation
    /// and was invisible to a single-needle scan (guard-prover).
    ///
    /// Two things about how they are spelled, both caught by the
    /// anchors below rather than by reading — which is what those
    /// are for. **No trailing paren**: `callSites` appends the
    /// paren requirement itself, so a needle carrying one searches
    /// for `glassEffect((` and matches nothing. **No leading
    /// dot**: inside the modifier the call is made on an implicit
    /// `self`, so a dot-prefixed needle misses the home file.
    /// Undotted also means `needsBoundary` applies, which keeps a
    /// longer identifier from answering for it; comments are
    /// stripped first, so the docstrings naming these do not
    /// count.
    private static let calls = [
        "glassEffect", "glassBackgroundEffect",
        "GlassEffectContainer", "glassEffectID",
    ]

    /// The one the home file must still make, so the anchor below
    /// names a specific call rather than "any of them".
    private static let call = "glassEffect"

    /// Files that spell the platform call outside the home, each
    /// naming its ruling — the one copy of who is exempt.
    ///
    /// **Empty, deliberately.** A surface adopting glass calls
    /// `glassChrome(in:)` and gets the fallback for free; one
    /// that needs something the modifier cannot express widens
    /// the modifier rather than reaching past it.
    private static let allowed: [String: String] = [:]

    private static var guiRoot: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
    }

    @Test("The platform glass call has exactly one home")
    func glassHasOneHome() throws {
        var strays: [String] = []
        var hits: Set<String> = []
        var anchored: Set<String> = []
        var scanned = 0
        for file in try SourceScan.swiftSources(under: Self.guiRoot) {
            scanned += 1
            let name = file.lastPathComponent
            let text = Array(try SourceScan.strippedSource(at: file))
            let spelled = Self.calls.filter {
                !SourceScan.callSites(in: text, for: $0).isEmpty
            }
            guard !spelled.isEmpty else { continue }
            hits.insert(name)
            if spelled.contains(Self.call) { anchored.insert(name) }
            guard Self.allowed[name] == nil else { continue }
            if name != Self.home {
                strays.append("\(name): \(spelled.joined(separator: ", "))")
            }
        }
        // A clause whose expected result is one match passes for
        // having scanned nothing. A FLOOR against a tree of
        // hundreds, never the live count.
        #expect(scanned >= 100, "scanned \(scanned) files")
        // And the needle must still MATCH: without this the
        // clause below empties in silence the day the call is
        // renamed or the modifier stops making it.
        #expect(
            anchored.contains(Self.home),
            "\(Self.home) no longer spells \(Self.call)"
        )
        #expect(
            strays.isEmpty,
            """
            spells a platform glass call outside \(Self.home) — \
            adopt glass through `glassChrome(in:)`, which carries \
            the fallback and the clip, or rule it in `allowed`: \
            \(strays)
            """
        )
        #expect(
            Self.allowed.keys.allSatisfy(hits.contains),
            "a ruling fires on nothing: \(Self.allowed.keys)"
        )
    }

    /// **The clip is applied ONCE, outside the branch.**
    ///
    /// This is the clause the modifier's own premise needs. Its
    /// first cut clipped only in the fallback —
    /// `glassEffect(_:in:)` draws the effect in a shape without
    /// clipping content to it — so the one home built to stop the
    /// two halves disagreeing shipped them disagreeing about
    /// whether the shape clips. Nothing rendered wrong, because
    /// every child of the one adopting surface is inset past the
    /// 12pt corner arc; the first full-bleed row would have had
    /// square corners on macOS 26 and round ones below
    /// (ui-designer).
    ///
    /// Pinned by WHERE the clip sits, not by how many there are.
    /// A count alone was not enough: it tells two clips from one,
    /// but not one clip OUTSIDE the branch from one clip inside a
    /// single branch — and the second is the shipped defect
    /// exactly. That version stayed green on it (guard-prover),
    /// so the clause reads the two bodies apart.
    @Test("One clip serves both branches")
    func theClipIsSharedByBothBranches() throws {
        let file = Self.guiRoot
            .appendingPathComponent(
                "Settings/Components/Common/\(Self.home)"
            )
        let source = try SourceScan.strippedSource(at: file)
        let shared = try #require(
            SourceScan.declarationBody(
                after: "func glassChrome",
                in: source
            ),
            "glassChrome's body did not parse"
        )
        let branch = try #require(
            SourceScan.declarationBody(
                after: "func glassGround",
                in: source
            ),
            "glassGround's body did not parse"
        )
        #expect(
            SourceScan.callSites(
                in: Array(shared),
                for: "clipShape"
            ).count == 1,
            "glassChrome does not clip exactly once: \(shared)"
        )
        #expect(
            SourceScan.callSites(
                in: Array(branch),
                for: "clipShape"
            ).isEmpty,
            """
            glassGround clips inside the availability branch, so \
            one half promises a clip the other does not: \(branch)
            """
        )
        // And the branch is still there to be shared: a file that
        // stopped branching would satisfy both clauses trivially.
        #expect(
            branch.contains("#available(macOS 26"),
            "\(Self.home) no longer branches on availability"
        )
    }
}
