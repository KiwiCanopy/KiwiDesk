import Foundation
import Testing

@testable import KiwiDesk

/// A help string that NAMES another control interpolates that
/// control's own key; it never re-types the label as literal
/// text (#818).
///
/// The failure this exists for is not hypothetical. A quotation
/// is a hand-kept mirror, and every locale then holds the label
/// and its quotation as two independent strings that must agree
/// forever with nothing checking that they do: `de` drifted to
/// „Öffnet eigenen Track" against a control reading "Öffnet
/// seinen eigenen Track", `ja` dropped the option mapping the
/// sentence exists for, and `profiles.current_setup_note` said
/// "Save a Copy As…" while its button said "Save a copy…" — a
/// mirror broken in ENGLISH, with one author and one language.
///
/// `gui.md` requires a second family of stitched sentence to
/// bring its own guard; this is that guard for the quoting
/// family.
///
/// **The frame/label pairs are DERIVED, never listed here.** The
/// first cut of this suite hand-listed them, and `guard-prover`
/// proved that register could name the WRONG key and stay green:
/// pointed at `destination.colors` where the frame really
/// interpolates `destination.gaps_borders`, all three tests
/// passed. A hand-kept list of the very thing under test is the
/// defect the suite condemns in its own opening paragraph, one
/// level up — `rule-authoring.md`'s "a number-pin must derive
/// the number" applied to a key-pin. So the pairs are parsed out
/// of the call sites: an `L(` whose argument list contains a
/// nested `L(` IS a frame, and the nested keys in source order
/// ARE its labels. Nobody writes them down, so nobody can write
/// them down wrongly.
///
/// What it still cannot see, stated so it is not mistaken for
/// coverage: a frame that re-types a label and interpolates
/// NOTHING has no nested `L(` and so is not discovered at all.
/// That was measured rather than assumed before settling for it
/// — only 2 of the ~24 frames in this class quote with quotation
/// marks, so a quoted-span predicate catches almost none, and a
/// bare-substring predicate over the words involved (`Start`,
/// `Fill`, `Item`, `Boxed`, `Focus`) returns 253 hits of which
/// ~24 are real. An exemption map at a 90 % false-positive rate
/// is how a guard becomes noise, so that half is prevented by
/// interpolating on sight and this suite holds the frames that
/// already do.
@Suite("Interpolated control labels (#818)")
struct InterpolatedLabelTests {
    /// Frames already converted, and how many control labels
    /// each interpolates today. A **floor**, and deliberately
    /// not a mirror of the keys: the keys still come only from
    /// the scan, so this cannot name a wrong one — the defect
    /// that killed the first cut.
    ///
    /// It exists because `guard-prover` showed the derived scan
    /// alone cannot see a FULL revert. Put the literal label
    /// back and drop the nested `L(` argument, and the label
    /// leaves the derived register with it: the specifier count
    /// and the expected count fall together, every assertion
    /// still passes, and the revert has erased its own evidence.
    /// A floor is the only thing that survives that, because it
    /// is the one number the call site cannot restate.
    /// `colors.unfocused_off.help` is the family's precedent and
    /// is deliberately ABSENT: it interpolates a destination
    /// title through a computed property
    /// (`AdvancedColorsGates.gapsAndBorders`), not an inline
    /// `L(`, so the scan below cannot see it — and that is the
    /// scan's stated blind spot, not an oversight. A frame that
    /// reaches its label through any accessor is invisible here;
    /// only an inline `L("key", …)` argument is discovered.
    static let converted: [String: Int] = [
        "track.new_window_position.help": 4,
        "space_override.slot_size.help": 4,
        "onboarding.grant.body": 1,
        "profiles.current_setup_note": 1,
    ]

    private static func english() throws -> [String: String] {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources")
            .appendingPathComponent("KiwiDeskCore")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Locales")
            .appendingPathComponent("en.json")
        return try JSONDecoder().decode(
            [String: String].self,
            from: Data(contentsOf: url)
        )
    }

    /// The scan found the frames that exist. An empty result
    /// means the parser broke, not that the tree is clean — the
    /// failure mode `rule-authoring.md` names as a guard passing
    /// "for having found no violations rather than for there
    /// being none".
    @Test("the scan finds the interpolating frames")
    func scanIsNotEmpty() throws {
        let frames = try SourceScan.interpolatingFrames()
        #expect(
            frames.count >= 4,
            """
            found \(frames.count) interpolating frame(s) — the \
            call-site parser is broken, not the tree. At least \
            track.new_window_position.help, \
            space_override.slot_size.help, onboarding.grant.body \
            and profiles.current_setup_note interpolate a label.
            """
        )
        let keys = Set(frames.map(\.key))
        for expected in [
            "track.new_window_position.help",
            "space_override.slot_size.help",
        ] {
            #expect(
                keys.contains(expected),
                "the scan lost \(expected)"
            )
        }
    }

    /// Every key the scan derived is real. Derived rather than
    /// listed, so this can only fail on a call site naming a key
    /// that no locale carries — a raw key on screen.
    @Test("every derived key resolves")
    func derivedKeysResolve() throws {
        let en = try Self.english()
        for frame in try SourceScan.interpolatingFrames() {
            #expect(
                en[frame.key]?.isEmpty == false,
                "\(frame.file): frame key \(frame.key) is not in en.json"
            )
            for label in frame.labels {
                #expect(
                    en[label]?.isEmpty == false,
                    "\(frame.file): \(label) is not in en.json"
                )
            }
        }
    }

    /// The frame carries a positional specifier for each label
    /// it names. Reverting one to literal text drops a
    /// specifier and reds here.
    @Test("each named label has a specifier to land in")
    func labelsHaveSpecifiers() throws {
        let en = try Self.english()
        for frame in try SourceScan.interpolatingFrames() {
            guard let value = en[frame.key] else { continue }
            let found = (1...9).filter {
                value.contains("%\($0)$@")
            }
            #expect(
                found.count >= frame.slots,
                """
                \(frame.key) passes \(frame.slots) interpolated \
                argument(s) but carries \(found.count) \
                positional specifier(s) — a label re-typed as \
                literal text is a mirror no locale can keep in \
                step.
                """
            )
        }
    }

    /// The frame does NOT contain the label's own English as
    /// literal text. This is the assertion that reds when a
    /// conversion is reverted.
    @Test("no frame re-types a label it names")
    func framesDoNotRetypeLabels() throws {
        let en = try Self.english()
        for frame in try SourceScan.interpolatingFrames() {
            guard let value = en[frame.key] else { continue }
            for label in frame.labels {
                guard let text = en[label], !text.isEmpty else {
                    continue
                }
                #expect(
                    !value.contains(text),
                    """
                    \(frame.key) contains the literal text of \
                    \(label) ("\(text)") instead of \
                    interpolating it. Author the frame with a \
                    positional specifier and pass \
                    L("\(label)", …) as the argument.
                    """
                )
            }
        }
    }

    /// A converted frame never goes back to literal text. This
    /// is the assertion the derived scan cannot make about
    /// itself — see `converted`.
    @Test("a converted frame keeps interpolating")
    func conversionsHold() throws {
        let frames = try SourceScan.interpolatingFrames()
        for (key, floor) in Self.converted {
            let found = frames.filter { $0.key == key }
            #expect(
                !found.isEmpty,
                """
                \(key) interpolates nothing any more — it was \
                converted away from quoting a label as literal \
                text (#818) and has been reverted.
                """
            )
            let labels = found.map(\.labels.count).max() ?? 0
            #expect(
                labels >= floor,
                """
                \(key) interpolates \(labels) control label(s), \
                down from \(floor) — a label went back to \
                literal text, which no locale can keep in step.
                """
            )
        }
    }
}
