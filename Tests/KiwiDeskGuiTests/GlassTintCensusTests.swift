import Foundation
import Testing

/// **The home file's own shape** (#1297).
///
/// `GlassTintSeamTests` holds the two Core-wide routing clauses;
/// this holds `GlassTint` itself, and it is the **fail-shut
/// half**. Every clause there exempts the home file by design, so
/// without a census a second member added INSIDE `GlassTint` that
/// paints a Fill without the clamp ships green — which is #1297
/// one file inward. Split from that suite at the §2.1 ceiling.
@Suite("GlassTint census (#1297)")
struct GlassTintCensusTests {
    /// Every member of the home file that opens a body, paired
    /// with what that body must name.
    ///
    /// `maxAlpha` is a stored `let` and deliberately absent:
    /// `memberBodies` returns the members that open a body, which
    /// is the same residue `BarMotionSeamTests` states.
    private static let members: [String: [String]] = [
        "rendered": ["maxAlpha", "floorShare", "drawsGlass"],
        // Pure direction: reaches no colour, so it names none.
        "fade": [],
        "pinnedAppearance": ["drawsGlass", "wantsLightInk"],
        "sits": ["subviews"],
        "apply": ["rendered(", "fade(", "pinnedAppearance(", "sits("],
    ]

    /// Ways a member puts a colour on screen. One whose body
    /// reaches any of these and does not route through the mint
    /// is painting a colour the cap never saw.
    private static let painters = [
        "backgroundColor", "tintColor", "setFill", "fillColor",
        "colors",
    ]

    /// A literal painting site per `painters` entry, spelled out
    /// rather than built from the entry.
    ///
    /// **That is the whole point of the table.** The first cut
    /// interpolated the entry into the sample, so
    /// `body.contains(painter)` was true by construction and the
    /// control held for any string at all — `"notAPainter"`
    /// passed it (guard-prover). A sample built from the needle
    /// cannot tell a real spelling from a typed one.
    private static let paintingSites = [
        (site: "view.layer?.backgroundColor = c", entry: "backgroundColor"),
        (site: "glass.tintColor = NSColor.red", entry: "tintColor"),
        (site: "NSColor.red.setFill()", entry: "setFill"),
        (site: "let hex = style.fillColor", entry: "fillColor"),
        (site: "gradient.colors = [c.cgColor]", entry: "colors"),
    ]

    /// A body that paints nothing — the negative control that
    /// makes the positives mean something.
    private static let paintlessSite = "view.frame = rect"

    /// The mint, as a member's body names it.
    private static let mint = "rendered("

    private static var homeFile: URL {
        GlassTintSeamTests.coreRoot
            .appendingPathComponent("Bar/\(GlassTintSeamTests.home)")
    }

    @Test("Every member of GlassTint is censused and routed")
    func everyMemberIsCensused() throws {
        let source = try SourceScan.strippedSource(at: Self.homeFile)
        let members = SourceScan.memberBodies(in: source)
        let names = members.map(\.declaration)
        #expect(
            Set(names) == Set(Self.members.keys),
            """
            GlassTint's members and the census disagree — a member \
            added here owes an entry naming what its body reaches: \
            \(Set(names).symmetricDifference(Self.members.keys))
            """
        )
        #expect(
            names.count == Set(names).count,
            "an overload shares a census entry: \(names)"
        )
        for (name, body) in members {
            for needle in Self.members[name] ?? [] {
                #expect(
                    body.contains(needle),
                    "\(name) does not name \(needle)"
                )
            }
            // The fail-shut clause: a member that paints must say
            // where the colour came from. `rendered` IS the mint,
            // so it answers for itself.
            guard name != "rendered", Self.paintsUnclamped(body)
            else { continue }
            Issue.record("\(name) paints a colour without the clamp")
        }
    }

    /// **`apply` takes a Fill, never a colour** — which is what
    /// makes the routing clauses sufficient rather than merely
    /// suggestive. While the parameter was an `NSColor` a call
    /// site could hand in any colour at all and every other clause
    /// stayed green; the cap would have been one door away from a
    /// bypass again, one level up from the one #1297 was.
    @Test("No call site can hand a colour to a glass surface")
    func applyTakesAFillNotAColour() throws {
        let source = try SourceScan.strippedSource(at: Self.homeFile)
        let signature = try #require(
            SourceScan.callArguments(
                of: "static func apply(",
                in: source
            ),
            "apply's signature did not parse"
        )
        #expect(
            signature.contains("hex: String"),
            "apply no longer takes the Fill: \(signature)"
        )
        #expect(
            !signature.contains("NSColor"),
            """
            apply takes a colour, so a call site can substitute \
            one for the capped Fill: \(signature)
            """
        )
        // The fade's anchor is the shelf's edge, stated at every
        // call site (#1622): a default — or an optional one a nil
        // default stands in for — draws a shelf on any other edge
        // fading from the top, silently. So the parameter is read
        // WHOLE, never as a substring (guard-prover: `AppBarEdge?
        // = nil` passed a `contains` check).
        #expect(
            Self.parameter("edge", in: signature) == "edge: AppBarEdge",
            "apply's fade edge is not a required AppBarEdge: \(signature)"
        )
    }

    /// The parameter labelled `label` in a parsed signature, as
    /// spelled up to the next top-level comma; nil when absent.
    private static func parameter(
        _ label: String,
        in signature: String
    ) -> String? {
        signature.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { $0.hasPrefix("\(label):") }
    }

    /// The parameter reader, proved on the shapes it must tell
    /// apart — the clause above expects the one good spelling, so
    /// only these can show it refusing the others.
    @Test("The edge reader refuses a default and an optional")
    func edgeReaderRefusesDefaults() {
        let good = "_ b: V, hex: String, edge: AppBarEdge, x: Bool = false"
        #expect(Self.parameter("edge", in: good) == "edge: AppBarEdge")
        for bad in ["edge: AppBarEdge = .top", "edge: AppBarEdge? = nil"] {
            #expect(
                Self.parameter("edge", in: "hex: String, \(bad)")
                    != "edge: AppBarEdge",
                "the reader accepts \(bad)"
            )
        }
        #expect(Self.parameter("edge", in: "hex: String") == nil)
    }

    /// **The backdrop view paints nothing** (#1622). It lives in
    /// its own file, which the member census above does not scan
    /// and `GlassTintSeamTests` reaches only for files naming the
    /// glass, so a colour added here would be #1297 one file over.
    @Test("GlassBackdrop paints no colour of its own")
    func backdropPaintsNothing() throws {
        let file = GlassTintSeamTests.coreRoot
            .appendingPathComponent("Bar/GlassBackdrop.swift")
        let source = try SourceScan.strippedSource(at: file)
        // Present, so the negative below cannot pass on a moved
        // or emptied file.
        try #require(
            source.contains("makeBackingLayer"),
            "GlassBackdrop no longer builds its backing layer"
        )
        #expect(
            !Self.painters.contains(where: source.contains),
            "GlassBackdrop paints a colour beside GlassTint.apply"
        )
    }

    /// The `painters` needles, proved against literal sites.
    ///
    /// The census clause above expects no violation in the tree,
    /// so it exercises only `backgroundColor` — the one spelling
    /// `apply` happens to use. The other three are prospective,
    /// and this is the only place they can be proved real.
    @Test("Every painter needle trips the fail-shut clause")
    func painterNeedlesAreReal() {
        // Both directions: an entry with no site is one nothing
        // proves real, and a site for no entry is a spelling the
        // predicate has stopped watching.
        #expect(
            Set(Self.painters)
                == Set(Self.paintingSites.map(\.entry)),
            """
            painters and their sites disagree: \
            \(Set(Self.painters).symmetricDifference(
                Self.paintingSites.map(\.entry)))
            """
        )
        for (site, entry) in Self.paintingSites {
            #expect(
                Self.paintsUnclamped(site),
                "\(entry)'s site does not trip the clause: \(site)"
            )
            #expect(
                !Self.paintsUnclamped(
                    "guard let c = rendered(hex) else { return }; "
                        + site
                ),
                "the clause fires on \(entry) via the mint"
            )
        }
        // The negative control. Without it every assertion above
        // is satisfiable by a predicate that answers true for
        // everything, which is the shape the first cut had.
        #expect(
            !Self.paintsUnclamped(Self.paintlessSite),
            "the clause fires on a body that paints nothing"
        )
    }

    /// A member body that puts a colour on screen without routing
    /// through the clamp — the shape #1297 was, one file inward.
    /// Shared with the control above so it exercises the predicate
    /// the census actually uses, rather than a second copy that
    /// could drift from it.
    private static func paintsUnclamped(_ body: String) -> Bool {
        painters.contains(where: body.contains)
            && !body.contains(mint)
    }
}
