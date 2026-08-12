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
///
/// Second blind spot, and the sharper one: **the floor counts
/// labels, not identities.** Swap one nested `L(` for a
/// different key and the count is unchanged, the scan re-derives
/// the new key, and every assertion passes — `guard-prover` ran
/// exactly that mutation and it went green. So a sentence can
/// still come to name a control it does not mean, which is the
/// #519 class surviving conversion in a new form. The retired
/// `BarHelpLabelReferenceTests` half could not have caught it
/// post-conversion either: by then the English is a specifier,
/// not the label. Closing it wants a derivation from the
/// settings census — a frame's nested keys against the label
/// keys of the `SettingKey` cases it claims to name — never a
/// hand-listed pair, which is the defect that killed this
/// suite's first cut.
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
    /// The `colors.*_off.help` family USED to be absent here,
    /// on the ground that a frame reaching its label through a
    /// property was beyond a source scan. That is no longer true
    /// and the exemption is gone: `SourceScan
    /// .destinationTitleKeys` resolves
    /// `SettingsDestination.<case>.title` out of the switch, so
    /// those seven frames and `layout_defaults.spaces_using.none`
    /// are discovered and floored like any other. What remains
    /// invisible is a label reached through a LOCAL alias — which
    /// is why `AdvancedColorsHelp` no longer has one.
    /// The four below `track.…` were never #818 conversions —
    /// they already interpolated a label, and the scan found
    /// them. They are listed anyway, because the floor's job is
    /// to notice a frame going back to literal text and that is
    /// worth having wherever it interpolates, not only where a
    /// conversion put it. Two shapes to know when adding one:
    /// `layout.schematic.grid.ax` picks between two labels for
    /// ONE slot with a ternary (so 2), and `home.card.ax_value`
    /// has two call sites of which only one interpolates a key
    /// (the count is the larger).
    /// The twelve below `profiles.current_setup_note` are the
    /// `i18n/terminology-round` batch. Five of them had ALREADY
    /// drifted in a shipped catalog before the conversion —
    /// `es` named the boxed style "En casillas" against a picker
    /// reading "En caja", `it` a colour row "Elemento sotto il
    /// puntatore" against a row reading "Elemento al passaggio
    /// mouse" — which is the strongest evidence this suite's
    /// premise is right rather than tidy. The count here is
    /// LABELS, which is what the scan derives — not the
    /// specifier count, which a ternary can make smaller. The
    /// two `*.alignment.label.help` frames briefly spent `%1$@`
    /// twice, and that was backed out: `placeholder_drift`
    /// compares a multiset, so a repeat makes a stylistic second
    /// mention mandatory in every language and fails a
    /// translation that pronominalises it. `gui.md` ▸ Strings
    /// now bans it outright.
    static let converted: [String: Int] = [
        "home.card.ax_value": 1,
        "keyboard.layout.value": 1,
        "layout.schematic.grid.ax": 2,
        "search.result_mode_ax": 1,
        "track.new_window_position.help": 4,
        "space_override.slot_size.help": 4,
        "profiles.current_setup_note": 1,
        "app_bar.alignment.label.help": 2,
        "app_bar.background_fit.boxed_only": 1,
        "app_bar.color.gap_only": 1,
        "app_bar.icon_source.help": 5,
        "app_bar.icon_source.name_only": 2,
        "lua_editor.adopt_help.body": 1,
        "shortcuts.import.help": 1,
        "space_bar.alignment.label.help": 2,
        "space_bar.background_fit.boxed_only": 1,
        "space_bar.color.focused_item.help": 2,
        "space_bar.icon_source.help": 1,
        "spaces.delete_confirm.message": 2,
        // The eight below were ALWAYS interpolating and were
        // invisible until the scan learned
        // `SettingsDestination.<case>.title` — they reach a
        // destination title through that property rather than an
        // inline `L(`, which is right: the English is authored
        // once, in the switch. Before the scan could resolve it
        // they had no floor at all, so a revert to literal text
        // would have passed unseen in every one of them.
        // Two, not one: #705 added the name of the block that
        // holds the switch beside the destination, the vague
        // "turn one on" having left the referent to the reader.
        // Its Bars-page twin joins the register for the same
        // change.
        "colors.app_bar_off.help": 2,
        "app_bar.no_layout.help": 1,
        "colors.border_off.help": 1,
        "colors.drag_border_off.help": 1,
        "colors.drag_fill_off.help": 1,
        "colors.drag_off.help": 1,
        "colors.space_bar_off.help": 1,
        "colors.unfocused_off.help": 1,
        "layout_defaults.spaces_using.none": 1,
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
        // Total, not a sample. The floor only protects the
        // frames it lists, so a conversion that forgets its
        // entry silently has no full-revert protection at all —
        // which four discovered frames were missing when this
        // check was added. The keys still come only from the
        // scan; the entry contributes just the number a call
        // site cannot restate.
        for frame in frames {
            #expect(
                Self.converted[frame.key] != nil,
                """
                \(frame.key) (\(frame.file)) interpolates a \
                label but has no floor in `converted` — add it \
                with the count it interpolates today, or a \
                revert to literal text will pass unseen.
                """
            )
        }
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
            // EQUALITY, not `>=`. `guard-prover` mutated an entry
            // from 4 to 1 with no call site touched and the suite
            // stayed green: a `>=` floor cannot see a
            // mis-transcribed LOW number, so a typo silently
            // re-rates that frame's protection down to whatever
            // was written and the guard then watches a quarter of
            // what it should. Equality costs an entry bump when a
            // frame gains a label — which is an author-visible
            // cost, on screen beside the register, and the whole
            // point of keeping the number by hand.
            #expect(
                labels == floor,
                """
                \(key) interpolates \(labels) control label(s) \
                against a registered \(floor). Fewer means a \
                label went back to literal text, which no locale \
                can keep in step; more means the frame gained one \
                and this entry needs bumping.
                """
            )
        }
    }
}
