import Foundation
import Testing

/// The glide's two INVERTED seams (#1082). Both default inert on
/// `HoldRepeat` and are opted into live by `KiwiCore+HoldGlide`,
/// the polarity tests.md names — a live default would build a
/// `CADisplayLink` on a real screen in every suite that arms a
/// hold, and would dispatch a real `resize` from every one that
/// fires a chord.
///
/// tests.md requires an inverted seam to be guarded from BOTH
/// sides, and that is the whole reason this suite exists rather
/// than a behavioural test — but the two seams are NOT equally
/// exposed, and the difference is worth stating rather than
/// averaging (guard-prover, #1082):
/// - **`startFrames` is guarded here and nowhere else.** Every
///   suite hands in its own frame-clock fake, so deleting the
///   production wiring leaves the rest of the tree green while a
///   held chord silently stops gliding — the inert default is a
///   working no-op, not a crash. Measured: with that assignment
///   deleted, this suite is the only thing that reds.
/// - **`applyGlideStep` has a second net**, because
///   `HoldGlideFixture` deliberately does not stub it — deleting
///   its wiring also reds `HoldRepeatWiringTests` ▸
///   `chordArmsGlidesAndReleases`. Still pinned here, since that
///   net is one suite's choice and could be stubbed away in a
///   refactor without anyone noticing what it was carrying.
///
/// Duplicating either is the other direction: two frame clocks on
/// one hold double every step. So both needles are pinned by
/// EXACT COUNT rather than by "no strays".
///
/// What the seams DO once wired is `HoldRepeatWiringTests`
/// (a real chord, real frames, a real `resize`); the ladder they
/// hang off is `HoldRepeatTests`.
@Suite("Hold-glide seams stay wired, and singular (#1082)")
struct HoldGlideSeamTests {
    private static let root = SourceScan.repoRoot(
        from: #filePath
    )
    private static let productionTrees = [
        root.appendingPathComponent("Sources/KiwiDeskCore"),
        root.appendingPathComponent("Sources/KiwiDesk"),
    ]

    /// The one file allowed to assign either seam. Named rather
    /// than described: a second assignment site is exactly the
    /// drift this counts.
    private static let wiringFile = "KiwiCore+HoldGlide.swift"

    /// The bootstrap call that reaches that file at all. Zero
    /// here is the silent direction — the seams stay at their
    /// inert defaults and the feature is off with nothing red.
    private static let bootstrapFile = "KiwiCore+Bootstrap.swift"

    private static func sites(
        of needle: String
    ) throws -> [MachineTouchSite] {
        try productionTrees.flatMap {
            try SourceScan.identifierSites(of: needle, under: $0)
        }
    }

    @Test("each glide seam is assigned exactly once, in one file")
    func seamsAreAssignedOnce() throws {
        // The needles carry the assignment, not the property
        // name: reading `holdRepeat.isGliding` elsewhere is
        // legitimate (the resize paths do), and a bare property
        // needle would count those and read as duplication.
        for needle in [
            "holdRepeat.applyGlideStep =",
            "holdRepeat.startFrames =",
        ] {
            let assigned = try Self.sites(of: needle)
            #expect(
                assigned.count == 1,
                """
                expected exactly one `\(needle)` site, found \
                \(assigned.count). Zero means the seam keeps its \
                INERT default and a held chord stops gliding with \
                nothing else red; two means two live objects on \
                one hold: \
                \(assigned.map(\.site).joined(separator: ", "))
                """
            )
            #expect(
                assigned.allSatisfy {
                    $0.file.lastPathComponent == Self.wiringFile
                }
            )
        }
    }

    @Test("the wiring is reached from bootstrap, exactly once")
    func wiringIsReachedFromBootstrap() throws {
        // Assigning the seams in a function nobody calls is the
        // same silent failure one level up, and the count above
        // cannot see it. `wireHoldGlide` is declared once and
        // called once, so the needle's own declaration is the
        // second site — pin two and name which is which, rather
        // than loosening to "at least one".
        let all = try Self.sites(of: "wireHoldGlide")
        #expect(
            all.count == 2,
            """
            expected `wireHoldGlide` to be declared once and \
            called once, found \(all.count): \
            \(all.map(\.site).joined(separator: ", "))
            """
        )
        let files = Set(all.map(\.file.lastPathComponent))
        #expect(files == [Self.wiringFile, Self.bootstrapFile])
    }

    @Test("the frame clock is the per-monitor driver, not a timer")
    func glideRidesTheDisplayLink() throws {
        // The per-monitor rule (input-and-animation.md): a glide
        // ticking off a `Timer` or a dispatch source would run at
        // a rate unrelated to the display, which is the whole
        // defect #1082 replaced — and it would drop the driver's
        // clamped `dt` and its starved-clock report (#1084), the
        // one honest device check that the ramp is ticked at all.
        let drivers = try Self.sites(of: "DisplayLinkDriver(")
        let glideDrivers = drivers.filter {
            $0.file.lastPathComponent == Self.wiringFile
        }
        #expect(
            glideDrivers.count == 1,
            """
            expected the glide to build exactly one \
            DisplayLinkDriver, found \(glideDrivers.count)
            """
        )
        // And nothing in that file reaches for a timer instead.
        for banned in ["Timer(", "Timer.scheduled", "DispatchSourceTimer"] {
            let strays = try Self.sites(of: banned).filter {
                $0.file.lastPathComponent == Self.wiringFile
            }
            #expect(
                strays.isEmpty,
                .init(
                    rawValue: "the glide's clock must be the "
                        + "DisplayLink, found \(banned) at "
                        + strays.map(\.site)
                        .joined(separator: ", ")
                )
            )
        }
    }
}
