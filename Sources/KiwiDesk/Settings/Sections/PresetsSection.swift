import KiwiDeskCore
import SwiftUI

/// Whole App ▸ Profiles ▸ **Start from a preset** (#53, rebuilt
/// in #678 turn 13a): the built-in per-screen-count layouts.
///
/// Grouped by screen count, and the live count leads under a
/// heading that names it ("For your 3 screens"). Every other
/// count folds into one disclosure: a preset for hardware that is
/// not plugged in cannot be applied, so it is a reference, not an
/// offer — and eight cards of reference above the user's own
/// three is what the flat list used to put on screen.
///
/// The group heading carries the screen number, so the cards do
/// not repeat it.
struct PresetsSection: View {
    @ObservedObject var model: SettingsModel
    @State private var otherSetupsExpanded = false

    var body: some View {
        SettingsSection(
            SettingsCatalog.profiles.presetsCard,
            caption: rowsCaption
        ) {
            if model.profileSummaries.isEmpty {
                // Zero-profile spotlight (ui-designer
                // 2026-07-19): the lead-in labels the bootstrap
                // the section already is; state-driven, gone once
                // any profile exists.
                Text(startHereText)
                    .font(.callout)
                    .fontWeight(.medium)
            }
            liveGroup
            otherSetups
        }
    }

    /// Hoisted out of the builder (§5 shallow-body guardrail:
    /// concatenated literals inside one body expression).
    private var startHereText: String {
        L(
            "presets.start_here",
            "Start here — apply a preset for your "
                + "setup, then adjust anything from "
                + "any tab."
        )
    }

    private var rowsCaption: String {
        L(
            "presets.caption",
            "Applying one saves it as a real profile you can "
                + "then edit."
        )
    }

    // MARK: - Groups

    private var liveCount: Int { model.displays.count }

    // Both preset lists come from the family seam that records
    // what `presetsApply` expands to, so the guard over that
    // expansion watches the cards this section actually draws.
    @ViewBuilder private var liveGroup: some View {
        let presets = ProfilesFamilyRows.presets(
            forScreens: liveCount
        )
        if presets.isEmpty {
            Text(noPresetsForCount)
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            SettingsGroupHeader(liveHeading)
                .padding(.top, 4)
            ForEach(presets, id: \.name) { presetRow($0) }
        }
    }

    private var liveHeading: String {
        liveCount == 1
            ? L("presets.for_your.one", "For your 1 screen")
            : L(
                "presets.for_your.many",
                "For your %1$d screens",
                liveCount
            )
    }

    private var noPresetsForCount: String {
        L(
            "presets.none_for_count",
            "No built-in layout plans for this many screens — "
                + "the ones below still apply once you connect "
                + "the screens they are for."
        )
    }

    /// Every preset for a count that is NOT connected, behind one
    /// disclosure that says how many are in there.
    @ViewBuilder private var otherSetups: some View {
        let others = ProfilesFamilyRows.presets(
            excludingScreens: liveCount
        )
        if !others.isEmpty {
            SettingsDisclosure(
                SettingsCatalog.profiles.presetsOther,
                chrome: .inline(font: .subheadline),
                isExpanded: $otherSetupsExpanded,
                scrollHoisted: true
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(otherCounts(others), id: \.self) {
                        count in
                        otherCountGroup(count, in: others)
                    }
                }
                .padding(.top, 6)
            } accessory: {
                Text("\(others.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func otherCounts(
        _ others: [StandardLayout]
    ) -> [Int] {
        Array(Set(others.map(\.screenCount))).sorted()
    }

    @ViewBuilder private func otherCountGroup(
        _ count: Int,
        in others: [StandardLayout]
    ) -> some View {
        Text(
            count == 1
                ? L("profiles.screens.one", "1 screen")
                : L(
                    "profiles.screens.many",
                    "%1$d screens",
                    count
                )
        )
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)
        .padding(.top, 4)
        ForEach(
            others.filter { $0.screenCount == count },
            id: \.name
        ) { presetRow($0) }
    }

    // MARK: - Rows

    private func presetRow(
        _ layout: StandardLayout
    ) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(layout.displayName).font(.headline)
                    if layout.isStandard {
                        BadgeChip(
                            label: L(
                                "presets.standard_badge",
                                "standard"
                            )
                        )
                    }
                }
                Text(layout.displaySummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                PresetScreenCard(layout: layout)
            }
            Spacer()
            applyButton(layout)
        }
        .padding(.vertical, 2)
    }

    /// Zero-profile spotlight (ui-designer 2026-07-19): ONE
    /// Apply goes accent-prominent until the first profile
    /// exists — the appliable count's Standard preset, so the
    /// spotlight stays a single primary (review 2026-07-19:
    /// prominence on every appliable preset put three accent
    /// buttons in one field, four with the footer's).
    @ViewBuilder private func applyButton(
        _ layout: StandardLayout
    ) -> some View {
        // Greyed, never hidden (#171) — with the reason, because
        // "why is Apply dead" has two different answers and the
        // stored-profile one contradicts what the user just read
        // in the header (#518). Both answers are the resolver's:
        // a predicate re-derived here could grey a row the census
        // says is live.
        let reason = gates(layout).inertReason(
            for: .profiles(.presetsApply)
        )
        // Apply materializes a profile and reloads, so it
        // drops staged edits like the profile actions (#515).
        let button = Button(L("presets.apply", "Apply")) {
            model.discardingEdits(
                message: L(
                    "discard.apply_preset.message",
                    "Applying a preset replaces the edits you "
                        + "haven't saved."
                ),
                confirmLabel: L(
                    "discard.apply_preset.confirm",
                    "Discard & apply"
                )
            ) { model.applyStandardPreset(layout) }
        }
        .controlSize(.large)
        .disabled(reason != nil)
        .help(reason.map(ProfilesGateHelp.sentence) ?? "")
        if reason == nil, layout.isStandard,
            model.profileSummaries.isEmpty
        {
            button.buttonStyle(.borderedProminent)
        } else {
            button.buttonStyle(.bordered)
                .neutralButtonLabel()
        }
    }

    private func gates(
        _ layout: StandardLayout
    ) -> ProfilesGates {
        // `separateDisplaySpaces` reaches no arm this row can
        // hit, and it is passed anyway: the resolver takes no
        // default for it, so a call site that would rather not
        // think about it is made to. One snapshot on the model
        // means this costs nothing and cannot disagree with
        // what the bindings card resolves from.
        ProfilesGates(
            editingStoredProfile: model.editingStoredProfile,
            separateDisplaySpaces:
                model.displaysHaveSeparateSpaces,
            connectedScreens: liveCount,
            presetScreens: layout.screenCount
        )
    }
}
