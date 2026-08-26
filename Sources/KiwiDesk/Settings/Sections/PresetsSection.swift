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
    /// The shell's measured band — the ONE width
    /// derivation this grid is allowed to read.
    @Environment(\.settingsWidth) private var band
    @State private var otherSetupsExpanded = false
    /// The open preview sheet, or nil (#859).
    @State private var previewRequest: PresetPreviewRequest?

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
        // Hosted on the SECTION, not on a card. The cards are in
        // a `LazyVGrid`, which tears down rows it scrolls past,
        // and a sheet hosted inside a subtree its own presenter
        // can destroy dies with it — the lesson `SettingsView`
        // records for the one discard dialog, which sits above
        // the `editingLua` branch for exactly this reason. This
        // view's identity is stable for as long as the area is.
        //
        // **It states no focus destination, and that is correct
        // here.** gui.md requires one of every shape change, and
        // the shell states two itself — but those are NAVIGATIONS,
        // which replace the subtree that held the focus. A sheet
        // does not: the presenting tree survives, so AppKit
        // restores the previous first responder on dismissal.
        // Eye-confirmed on macOS 26.6.1, 2026-08-17 — with focus on
        // a control beforehand, Tab after closing resumes there;
        // the "first Tab lands on the search field" reading came
        // from opening the sheet with focus nowhere at all, which
        // is AppKit choosing the window's first responder and not
        // this sheet losing anything.
        //
        // A `@FocusState` restore was written here and BACKED OUT:
        // it would force focus onto the card that opened the sheet
        // even when the keyboard had been on a different card, so
        // it replaced a correct answer with a worse one. A future
        // sheet needs no destination for the same reason; a future
        // NAVIGATION still does.
        .sheet(item: $previewRequest) { request in
            PresetPreviewSheet(
                layout: request.layout,
                liveSizes: request.liveSizes
            ) { previewRequest = nil }
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

    /// Derived from `liveSizes`, so the "floor at one screen"
    /// rule is applied ONCE, in Core. Counting `model.displays`
    /// separately made the two disagree with nothing published:
    /// the live group said "no plans for this many screens" while
    /// a Starter for the nominal screen existed and was filtered
    /// out by `screenCount != 0` (architect review, 2026-08-11).
    private var liveCount: Int { liveSizes.count }

    /// The live screens in positional order, which the `Starter`
    /// preset is derived from. Ordered by the same helper the
    /// first-run seed uses, so the preset a user applies and the
    /// setup they were seeded with are the same thing.
    private var liveSizes: [CGSize] {
        StarterSetup.sizes(
            displays: model.displays,
            mainID: PositionalDisplays.liveMainID
        )
    }

    // Both preset lists come from the family seam that records
    // what `presetsApply` expands to, so the guard over that
    // expansion watches the cards this section actually draws.
    @ViewBuilder private var liveGroup: some View {
        let presets = ProfilesFamilyRows.presets(
            forScreens: liveCount,
            sizes: liveSizes
        )
        if presets.isEmpty {
            Text(noPresetsForCount)
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            SettingsGroupHeader(liveHeading)
                .padding(.top, 4)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(presets, id: \.name) {
                    presetCard($0, sizes: liveSizes)
                }
            }
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
                isExpanded: $otherSetupsExpanded,
                scrollHoisted: true,
                summary: "\(others.count)"
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(otherCounts(others), id: \.self) {
                        count in
                        otherCountGroup(count, in: others)
                    }
                }
                .padding(.top, 6)
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
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(
                others.filter { $0.screenCount == count },
                id: \.name
            ) { presetCard($0, sizes: nil) }
        }
    }

    // MARK: - Rows

    /// The card, with this section's own inputs supplied once
    /// rather than at both call sites.
    ///
    /// A wrapper rather than two direct `PresetCard(...)` calls,
    /// and deliberately: `ProfilesGateWiringTests` keys two needles
    /// on this file's `presetCard($0,sizes:liveSizes)` and
    /// `presetCard($0,sizes:nil)` spellings — the pin on which
    /// cards resolve against live hardware and which are drawn as
    /// plans. Keeping the wrapper means #859 moved the drawing
    /// without repointing that guard, which is a split "changing
    /// what a test claims with its bytes untouched"
    /// (tests.md ▸ Owed).
    private func presetCard(
        _ layout: StandardLayout,
        sizes: [CGSize]?
    ) -> some View {
        PresetCard(
            layout: layout,
            sizes: sizes,
            model: model,
            connectedScreens: liveCount
        ) { previewRequest = $0 }
    }

    /// The grid's columns — the BAND's cap, never a width this
    /// view measures for itself (`SettingsWidthClass` is the one
    /// derivation). `.flexible` rather than `.adaptive` so the
    /// cap is honoured: `.adaptive` cannot express "at most N".
    ///
    /// The minimum is `PresetCard`'s own floor rather than a
    /// number stated here (#862): the card knows what it has to
    /// hold, and the grid stating a second, smaller opinion is
    /// how the declared floor came to be a width no locale's
    /// button row fits in.
    private var columns: [GridItem] {
        Array(
            repeating: GridItem(
                .flexible(minimum: PresetCard.minimumWidth),
                spacing: 12
            ),
            count: band.presetColumnCap
        )
    }
}
