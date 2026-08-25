import Foundation
import Testing

@testable import KiwiDesk

/// `InterpolatedLabelTests`' floor register, split out under
/// AGENTS.md §2.1 when the `i18n/residue-round` batch (#830)
/// took the suite past the 350-line ceiling. It sits in its own
/// file for the reason `rule-authoring.md` gives for leaving a
/// count beside its register: an author adding a frame has every
/// other frame's count on screen while they do it.
///
/// The assertions, and what this floor can and cannot see, are in
/// `InterpolatedLabelTests.swift`.
extension InterpolatedLabelTests {
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
        // The two per-space remote-gate pointers (#841). One
        // control label each — the second specifier is
        // `CrossReferenceRow.linkSlot`, a destination link
        // rather than a control name, so it is not counted here.
        // The Spaces panel's default-arm caption: it names the
        // Layout Defaults pane, which it used to spell as text
        // — every locale then hand-mirrored the pane's name, and
        // the drafting round did exactly that (localization
        // audit, 2026-08-16).
        "spaces.preview.caption_default": 1,
        "scroll_grid.auto_size.xref": 1,
        "track.auto_tracks.xref": 1,
        // The `.gates` twins of the two above. They quoted the
        // same labels as literal text and were invisible to the
        // scan — a fully-quoting frame has no nested `L(` to
        // discover, the blind spot this suite's own header
        // records (re-review, 2026-08-16).
        "scroll_grid.auto_size.gates": 1,
        "track.auto_tracks.gates": 1,
        "home.card.ax_value": 1,
        "keyboard.layout.value": 1,
        "layout.schematic.grid.ax": 2,
        "search.result_mode_ax": 1,
        "track.new_window_position.help": 4,
        // Monocle's hide-style popover (#881): both option
        // names interpolated from their own keys, authored that
        // way from the start.
        "monocle.hide_style.help": 2,
        "space_override.slot_size.help": 4,
        "profiles.current_setup_note": 1,
        "app_bar.alignment.label.help": 2,
        "app_bar.background_fit.boxed_only": 1,
        "app_bar.color.gap_only": 1,
        "app_bar.icon_source.help": 5,
        "app_bar.icon_source.title_only": 2,
        "space_bar.title_cap.front_app_only": 1,
        "lua_editor.adopt_help.body": 1,
        "shortcuts.import.help": 1,
        "space_bar.alignment.label.help": 2,
        "space_bar.background_fit.boxed_only": 1,
        "space_bar.color.focused_item.help": 2,
        "space_bar.icon_source.help": 2,
        "spaces.delete_confirm.message": 2,
        // The entries below were ALWAYS interpolating and were
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
        // The `i18n/residue-round` batch (#830), in three
        // groups. No count is stated here on purpose: an earlier
        // draft of this comment claimed an arithmetic that did
        // not reconcile with the entries under it (code review,
        // 2026-08-17), which is the branch's own subject arriving
        // in the branch's own test. The entries are the register;
        // `conversionsHold` is what checks them.
        //
        // 1. #830's own table, produced by a detector and
        //    hand-confirmed months earlier. Some of its rows were
        //    already converted by the re-review that filed it, so
        //    it is read as a starting set rather than a register.
        //    One entry here is NOT from that table
        //    (`general.advanced.restart_on_crash.needs_login`) —
        //    it quotes the label #864 renamed and was found while
        //    fixing it.
        "border.controls.disabled": 1,
        "space_bar.disabled.help": 1,
        "scroll_grid.scroll_speed.animation_off": 1,
        "track.auto_tracks.limit_inert": 1,
        "monitors.not_connected.caption": 1,
        "menu.status.config_error.tooltip": 1,
        "border.fit_gaps.action_hint": 1,
        "border.fit_gaps.updated": 1,
        "border.fit_gaps.updated_inactive": 1,
        "footer.save.globals_only": 1,
        // desktops.clear_all.help left the register with
        // #888 — the "Clear all bindings" escape hatch retired
        // along with the separate-Spaces grey it existed for.
        "shortcuts.imported_note": 1,
        "key_recorder.live_apply_failed": 2,
        "key_recorder.revert_failed": 1,
        "key_recorder.revert_used_snapshot": 1,
        "lua_editor.adopt.title": 1,
        "lua_editor.adopt.message_dirty": 1,
        "layout_params.master_orientation.one_master": 1,
        "shortcuts.app_behavior.help": 2,
        "general.advanced.restart_on_crash.needs_login": 1,
        // 2. The `**`-marker glossaries. #830 asked that two be
        //    CHECKED rather than swept; the check converted them
        //    and found more of the same family. A bold marker
        //    wrapping a specifier is the frame's punctuation and
        //    the label is the argument, so the shape converts
        //    unchanged. Every `**%n$@**` frame in `en.json` is in
        //    this register — converting some would leave a picker
        //    naming its entries as text beside one that does not.
        "layout_params.overflow.stack.help": 2,
        "layout_params.split_strategy.help": 2,
        "layout_params.overflow.track.help": 2,
        "behavior.mouse.resize_action.help": 2,
        // 3. Found by re-running #830's own detector against
        //    this tree rather than trusting its table. Two are
        //    greyed-section reasons — the class that issue leads
        //    with, and `GapsBordersGateHelp` had THREE of its
        //    four quoting where the table named one. One is a
        //    fourth `border.fit_gaps.*` sibling, left while its
        //    three twins converted. The rest name a control the
        //    sentence sends the reader to find.
        //
        // `shortcuts.row.inherited.axhint` was in group 1 and is
        // deliberately NOT here: its label is not on screen for
        // the row it describes, so the frame stopped naming a
        // control at all. `KeybindingOverrideEnvironment` carries
        // the argument.
        "border.glow_size.disabled": 1,
        "drag.disabled.help": 1,
        "border.fit_gaps.updated_new": 1,
        "scroll_grid.animate_focus_shifts.help": 1,
        "sticky.caption": 2,
        "general.login_item.start_help": 1,
    ]
}
