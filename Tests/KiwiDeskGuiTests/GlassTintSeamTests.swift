import Foundation
import Testing

/// **A Fill becomes a colour on glass in one place** (#1297) —
/// the two Core-WIDE clauses.
///
/// `GlassTintCensusTests` holds the home file's own shape and
/// `GlassTintCapTests` holds what the cap does; these hold that
/// the surfaces still go through it, since a clamp proved correct
/// in a file nothing routes to clamps nothing. It is the shape
/// [bars.md](../../.claude/rules/bars.md) already imposes on
/// `BarMotion`: one home, routed through, applied exactly once.
///
/// **Scope is `Sources/KiwiDeskCore`, whole**, for
/// `BarMotionSeamTests`' reason rather than a new one — a glass
/// surface lands where it lands (`bars.md` calls #1229's overview
/// panel the next one), and a guard scoped to the directories
/// glass code occupies today cannot see the one that arrives
/// outside them. It stops at Core deliberately, and `bars.md`
/// carries the ruling: a `Sources/KiwiDesk` surface that tints
/// glass owes this suite a root.
///
/// **What is NOT here, and why.** An earlier cut policed "the
/// mint is called only in its home" with a scan. `rendered` is
/// `private` instead, so the compiler holds it and the clause was
/// deleted rather than kept as decoration (architect review).
@Suite("Glass colour routing (#1297)")
struct GlassTintSeamTests {
    /// The file a Fill becomes a colour in.
    static let home = "GlassTint.swift"

    /// The bypass channel itself. Nothing in Core drives it, and
    /// a Fill reaching it again is #1297 returning rather than a
    /// new feature — `docs/design-decisions.md` ▸ Liquid Glass
    /// has the measurement that says why it cannot carry one.
    private static let bypass = "tintColor"

    /// The subject, held present so the negative clauses cannot
    /// pass by the glass having been deleted or renamed out from
    /// under them (tests.md ▸ a negative pin fails OPEN).
    private static let subject = "NSGlassEffectView"

    /// What minting a colour from a stored Fill is spelled with,
    /// anywhere in Core. `GlassTint` may reach it; a file that
    /// also configures a glass surface may not.
    private static let mintPrimitive = "kiwiHex"

    /// How a view's appearance is pinned, anywhere in Core. The
    /// glass variant is decided from the Fill in `GlassTint.apply`
    /// (#1308); a second site pinning a glass view is a second
    /// rule, and the two bars diverge again the moment they
    /// disagree.
    ///
    /// The needle is a plain substring, read through
    /// `pinsAppearance` so the comparison that contains it
    /// (`.appearance == nil`) does not fire. It also matches any
    /// Core property spelled `appearance`, not only a view's — the
    /// trade for a needle a reformat cannot break. Residue, stated
    /// because it fails OPEN: an unqualified `appearance = …`
    /// inside an `NSView` subclass and a `setAppearance(` spelling
    /// are invisible here.
    private static let pin = ".appearance ="

    /// Whether `source` writes a view's appearance: the needle,
    /// less the `==` that contains it.
    private static func pinsAppearance(_ source: String) -> Bool {
        var rest = Substring(source)
        while let hit = rest.range(of: pin) {
            rest = rest[hit.upperBound...]
            if rest.first != "=" { return true }
        }
        return false
    }

    /// Files that drive `tintColor`, each naming its ruling — the
    /// one copy of who is exempt.
    ///
    /// **Empty, deliberately.** A surface that wants the channel
    /// back owes an entry here and an argument in
    /// `docs/design-decisions.md`, because the channel it is
    /// asking for cannot carry the colour it will look like it is
    /// asking for.
    private static let allowed: [String: String] = [:]

    static var coreRoot: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
    }

    @Test("Nothing in Core drives the glass tint channel")
    func noSurfaceDrivesTintColor() throws {
        var strays: [String] = []
        var hits: Set<String> = []
        var subjectSeen = false
        var scanned = 0
        for file in try SourceScan.swiftSources(under: Self.coreRoot) {
            scanned += 1
            let name = file.lastPathComponent
            let source = try SourceScan.strippedSource(at: file)
            let text = Array(source)
            if source.contains(Self.subject) { subjectSeen = true }
            guard source.contains(Self.bypass),
                SourceScan.mentions(Self.bypass, in: text)
            else { continue }
            // Recorded BEFORE the exemption, so the consumed-ruling
            // clause below can see an allow-listed file at all. The
            // first cut `continue`d here, which made that clause
            // unsatisfiable for any non-empty map — green only
            // because the map is empty (architect review).
            hits.insert(name)
            guard Self.allowed[name] == nil else { continue }
            strays.append(name)
        }
        // A clause expecting zero matches passes for having
        // scanned nothing. A FLOOR against a tree of hundreds,
        // never the live count, which every added Core file moves.
        #expect(scanned >= 200, "scanned \(scanned) files")
        // "names", not "builds": the needle matches `as?` casts
        // too, so deleting the one construction leaves this green
        // (guard-prover). Tightening it to `NSGlassEffectView(`
        // would buy the construction class and pay with a needle a
        // reformat can break. That class is covered behaviourally
        // instead, by `GlassTintCapTests.plateTakesNoColour`,
        // which requires `GlassPlate.make()`.
        #expect(
            subjectSeen,
            "no Core file names \(Self.subject) any more"
        )
        #expect(
            strays.isEmpty,
            """
            drives \(Self.bypass), which carries no hue and \
            dodges GlassTint.maxAlpha — colour a glass surface \
            through GlassTint.apply, or rule it in `allowed`: \
            \(strays)
            """
        )
        // Every ruling was CONSUMED. A ruling that outlives its
        // site is silent and still silencing, so the next real
        // driver at that file ships green too.
        #expect(
            Self.allowed.keys.allSatisfy(hits.contains),
            "a ruling fires on nothing: \(Self.allowed.keys)"
        )
    }

    /// **The glass variant is pinned in one place.**
    ///
    /// Scope is Core, whole, with the home file exempt — and the
    /// home file is held PRESENT as the pinning site, so this
    /// clause cannot pass by the pin having been deleted (tests.md
    /// ▸ a negative pin fails OPEN). No allow map: nothing in Core
    /// pinned an appearance before #1308, and a surface that needs
    /// one owes an argument in `docs/design-decisions.md` first.
    @Test("Nothing in Core pins a view's appearance beside GlassTint")
    func noSurfacePinsAppearance() throws {
        var strays: [String] = []
        var homePins = false
        var scanned = 0
        for file in try SourceScan.swiftSources(under: Self.coreRoot) {
            scanned += 1
            let name = file.lastPathComponent
            let source = try SourceScan.strippedSource(at: file)
            guard Self.pinsAppearance(source) else { continue }
            if name == Self.home {
                homePins = true
                continue
            }
            strays.append(name)
        }
        #expect(scanned >= 200, "scanned \(scanned) files")
        #expect(
            homePins,
            "\(Self.home) no longer pins the glass variant"
        )
        #expect(
            strays.isEmpty,
            """
            pins a view's appearance beside GlassTint.apply — the \
            glass variant is decided from the Fill there, once: \
            \(strays)
            """
        )
    }

    /// **A glass surface's own file mints no colour.**
    ///
    /// `GlassTintCensusTests` is scoped to `GlassTint.swift`, so
    /// the #1297 shape one file OVER rather than one file inward
    /// was invisible: a `GlassPlate.washProbe` painting
    /// `layer?.backgroundColor` from `NSColor(kiwiHex:)` left the
    /// whole suite green (guard-prover, measured).
    ///
    /// Scope is the files that name `NSGlassEffectView` — exactly
    /// those configuring a glass surface. It deliberately does
    /// not reach every Core file that paints a Fill near glass:
    /// the two `+Panel` files mint one legitimately for the SOLID
    /// plate, on the `!style.glassEnabled` path, and carrying
    /// them as permanent exemptions would pass the next real
    /// violation in the same files.
    ///
    /// **Residue, stated because it fails OPEN.** A Fill painted
    /// onto a backdrop beneath a glass view, from a file naming
    /// neither `tintColor` nor `NSGlassEffectView`, is invisible
    /// here — no needle tells it from the solid plate's mint,
    /// which is spelled identically.
    @Test("A glass surface's file mints no colour")
    func glassFilesMintNoColour() throws {
        var strays: [String] = []
        var scanned = 0
        for file in try SourceScan.swiftSources(under: Self.coreRoot) {
            scanned += 1
            let text = Array(try SourceScan.strippedSource(at: file))
            // `mentions`, not `callSites`: the latter demands a
            // paren immediately after the needle, and the mint is
            // spelled `NSColor(kiwiHex:` — so a `callSites` needle
            // for it matches nothing, and this clause was a no-op
            // on its first cut, green over the very mutation it
            // was written for (guard-prover).
            guard SourceScan.mentions(Self.subject, in: text),
                SourceScan.mentions(Self.mintPrimitive, in: text)
            else { continue }
            strays.append(file.lastPathComponent)
        }
        #expect(scanned >= 200, "scanned \(scanned) files")
        #expect(
            strays.isEmpty,
            """
            names \(Self.subject) and mints its own colour — a \
            glass surface takes GlassTint.apply, which reads the \
            Fill itself so the cap cannot be walked around: \
            \(strays)
            """
        )
    }

    /// **The needles still match what they name.**
    ///
    /// Both clauses above expect ZERO hits in the tree, so
    /// neither exercises its own needle: a typo in `bypass` or in
    /// `mintPrimitive` leaves its clause green forever, and
    /// `subjectSeen` anchors a DIFFERENT token — it covers "the
    /// glass was deleted" and not "the needle stopped being the
    /// bypass" (code review). So the needles are proved against
    /// synthetic sites, which is the only place they can be
    /// proved while the correct answer in the tree is nothing.
    @Test("Every needle matches the spelling it names")
    func needlesMatchTheirSubject() {
        let bypassSite = "glass.tintColor = NSColor.red"
        #expect(
            SourceScan.mentions(Self.bypass, in: Array(bypassSite)),
            "\(Self.bypass) no longer matches \(bypassSite)"
        )
        // A word boundary is what makes the clause a clause: a
        // needle firing inside a longer identifier would red on
        // innocent code and get deleted.
        //
        // The sample keeps the needle's OWN casing after an
        // identifier character, which is the only shape that
        // reaches the boundary branch. The first cut wrote
        // `barTintColorOverride` — capital T — so the needle did
        // not occur at all, the assertion passed on ABSENCE, and
        // forcing `needsBoundary` to false left it green
        // (guard-prover).
        #expect(
            !SourceScan.mentions(
                Self.bypass,
                in: Array("let bartintColorOverride = 1")
            ),
            "\(Self.bypass) matches inside a longer identifier"
        )
        #expect(
            SourceScan.mentions(
                Self.mintPrimitive,
                in: Array("NSColor(kiwiHex: style.fillColor)")
            ),
            "\(Self.mintPrimitive) no longer matches the mint"
        )
        // The pin predicate: the assignment it names, and the two
        // reads it must not — the comparison that CONTAINS the
        // needle is the one a plain `contains` fired on.
        #expect(
            Self.pinsAppearance(
                "glass.appearance = NSAppearance(named: .darkAqua)"
            ),
            "\(Self.pin) no longer matches a pin"
        )
        #expect(
            !Self.pinsAppearance("if view.appearance == nil { }"),
            "\(Self.pin) fires on a comparison"
        )
        #expect(
            !Self.pinsAppearance("let scheme = glass.effectiveAppearance"),
            "\(Self.pin) matches a read"
        )
    }
}
