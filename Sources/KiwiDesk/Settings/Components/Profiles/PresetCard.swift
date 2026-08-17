import KiwiDeskCore
import SwiftUI

/// One preset, as a CARD rather than a settings row (#789).
///
/// Its own view rather than a `PresetsSection` method, because
/// #859's second action pushed that file past the 350-line ceiling
/// and a method split into a sibling extension would have cost
/// five members their `private` — the shape 4b's architect review
/// already flagged in `ProfilesSection` and asked the next split to
/// undo rather than repeat. A widget also belongs in
/// `Components/<area>/` by gui.md's file layout, which is where a
/// `Sections/` extension would have left it in the wrong place.
///
/// Picture first, then the name, the summary, the space count, and
/// the actions — the order a comparison set wants, because the
/// picture is what the eye scans across and the prose is what it
/// reads once it has stopped. The old shape (title first, picture
/// third, Apply off to the right) read as a list of settings rows;
/// presets are offers.
///
/// **The actions are SIBLINGS of the text block, never buttons
/// inside a tappable card**: nesting one control in another is
/// broken on macOS whatever the design intent, and keeping Apply an
/// explicit per-card button is what lets it carry its own greyed
/// reason and the zero-profile spotlight. The same rule is why
/// #859's preview opens from a button beside it rather than by
/// making the picture tappable — the picture is a figure, and a
/// `.help` on a decorative image is hover-only.
///
/// They read look-then-apply, left to right, which is the order the
/// card is for: Apply materializes a profile and discards unsaved
/// edits behind a confirm, so the cheap reversible thing leads.
struct PresetCard: View {
    /// The card's own inset, on every edge.
    static let padding: CGFloat = 12
    /// The gap between the two action buttons.
    static let buttonRowSpacing: CGFloat = 8

    /// The narrowest width this card can actually be LAID OUT
    /// at — which is what makes a declared grid `minimum:` a
    /// floor rather than a wish (#862). `PresetsSection.columns`
    /// is its one reader.
    ///
    /// It has to hold the action row, because since #859 that row
    /// is two `.large` buttons rather than one, and the pair's
    /// width is eleven catalogs' business rather than this
    /// file's. The number is a LITERAL on purpose: deriving it
    /// from a live text measurement would put an AppKit metric
    /// read in a `body`, and — the sharper reason — it would make
    /// the guard vacuous, since a test comparing a derived floor
    /// against the derivation it came from asserts nothing — an
    /// assertion that recomputes both sides from the same
    /// constants cannot model anything those constants do not
    /// already say (`rule-authoring.md` ▸ a number-pin must
    /// derive the number).
    ///
    /// So the floor is declared here and `PresetGridFloorTests`
    /// measures the SHIPPED catalogs against it, reading these
    /// same three constants rather than restating them. Neither
    /// side of that comparison is the test's own invention, which
    /// is the whole point. The slack is deliberately small: this
    /// says "the narrowest the card works at", and a catalog that
    /// grows past it should red rather than quietly fit.
    ///
    /// The 200 pt it replaces predates the second button. #789
    /// ruled 200 "honest" about the PICTURE staying an outline
    /// plus glyph, which is a ruling about what the card draws
    /// and not about what it can hold, so raising it reopens
    /// nothing.
    static let minimumWidth: CGFloat = 280

    let layout: StandardLayout
    /// The live screen list for an APPLIABLE card and nil for the
    /// drawer — the card resolves its glyph against the same
    /// hardware the apply path will.
    let sizes: [CGSize]?
    @ObservedObject var model: SettingsModel
    /// How many screens are connected, for the gate. Passed in
    /// rather than re-read: `PresetsSection` derives it once from
    /// `liveSizes`, and a second read here could disagree with the
    /// list the section drew.
    let connectedScreens: Int
    let onPreview: (PresetPreviewRequest) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PresetScreenCard(layout: layout, liveSizes: sizes)
            titleRow
            Text(layout.displaySummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: Self.buttonRowSpacing) {
                layoutsButton
                applyButton
            }
        }
        .padding(Self.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(SettingsTheme.sunken)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(SettingsTheme.hairline)
        }
    }

    private var titleRow: some View {
        HStack(spacing: 6) {
            Text(layout.displayName).font(.headline)
            if layout.isStandard {
                BadgeChip(
                    label: L("presets.standard_badge", "standard")
                )
            }
        }
    }

    /// Open the preview sheet (#859).
    ///
    /// **Never gated, and that is the point.** Apply carries two
    /// greyed reasons — the screen count does not match, or a
    /// stored profile is being edited — and a user in either state
    /// is exactly the one who most wants to see what a preset
    /// contains. The sheet writes nothing, so it needs no gate and
    /// no discard confirm, which makes this the one control on the
    /// card that is always live.
    ///
    /// **Not called "Preview".** That word already names the detail
    /// panel in this same window (`panel.show_preview`,
    /// `panel.hide_preview`, `panel.move_preview`,
    /// `panel.live_preview`), and `docs/localization-naming.md` ▸
    /// Family C's first rule is that a word already naming another
    /// KiwiDesk concept loses whatever its count — a label reusing
    /// another feature's noun does not read as inconsistent, it
    /// reads as true about the wrong thing. That rule binds the
    /// ENGLISH author first (translation audit, 2026-08-16).
    /// "Layouts" is what the sheet holds, in the Family C noun that
    /// already owns the concept.
    private var layoutsButton: some View {
        Button(L("presets.layouts", "Layouts")) {
            onPreview(
                PresetPreviewRequest(
                    layout: layout,
                    liveSizes: sizes
                )
            )
        }
        .controlSize(.large)
        .settingsActionButton()
    }

    /// Zero-profile spotlight (ui-designer 2026-07-19): ONE Apply
    /// goes accent-prominent until the first profile exists — the
    /// appliable count's Standard preset, so the spotlight stays a
    /// single primary (review 2026-07-19: prominence on every
    /// appliable preset put three accent buttons in one field, four
    /// with the footer's).
    @ViewBuilder private var applyButton: some View {
        // Greyed, never hidden (#171) — with the reason, because
        // "why is Apply dead" has two different answers and the
        // stored-profile one contradicts what the user just read
        // in the header (#518). Both answers are the resolver's:
        // a predicate re-derived here could grey a row the census
        // says is live.
        let reason = gates.inertReason(
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
            button.settingsActionButton()
        }
    }

    private var gates: ProfilesGates {
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
            connectedScreens: connectedScreens,
            presetScreens: layout.screenCount
        )
    }
}
