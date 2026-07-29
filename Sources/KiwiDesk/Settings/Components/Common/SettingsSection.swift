import SwiftUI

/// The heading over a run of related sections (the App Bar
/// block in Appearance): the one registered level above a
/// section's `.headline`, so multi-section groups don't each
/// invent their own title style.
struct SettingsGroupHeader: View {
    let title: String

    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.title3)
            .fontWeight(.semibold)
    }
}

/// A titled group used across the dashboard sections. The
/// optional symbol puts a glyph before the title — used by the
/// per-mode sections so a layout's glyph (§6.3) travels with
/// its name. The optional caption is a one-sentence plain-words
/// explanation under the title; `subsection` shrinks the title
/// for groups that belong to a bigger one (Ghost / Drop zone
/// under Drag & drop).
///
/// The optional `help` renders a live `HelpButton` beside the
/// title — the block-gate anchor (#527): the header sits
/// OUTSIDE any `GreyOut` in `content`, so while a gate dims the
/// body (killing every `?` inside it, since `.disabled` is
/// cumulative), this one stays clickable and explains why the
/// block is off and how to enable it. Call sites pass it only
/// while their gate is active — once the block is live, its own
/// controls' help takes over and the anchor would gloss nothing.
struct SettingsSection<Content: View>: View {
    let title: String
    /// The catalog declaration this section was mounted as, or
    /// nil for the String init — whose remaining callers are the
    /// deliberately-unindexed computed titles (`%1$@ bar`). The
    /// whole descriptor rather than its id, so both halves of
    /// the pair below can only be fed from one control (#573).
    private let control: SettingsControl?
    let symbol: String?
    let caption: String?
    let subsection: Bool
    let help: String?
    @ViewBuilder let content: Content

    /// Computed-title init: renders identically but is NOT a
    /// search anchor. An indexable section takes a
    /// `SettingsControl` instead — declaring it in the catalog
    /// is what makes it findable, and the catalog's declaration
    /// is the one list (`SettingsCatalogArgumentTests` refuses a
    /// literal `L()` title here).
    init(
        _ title: String,
        symbol: String? = nil,
        caption: String? = nil,
        subsection: Bool = false,
        help: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.control = nil
        self.symbol = symbol
        self.caption = caption
        self.subsection = subsection
        self.help = help
        self.content = content()
    }

    /// The catalog init: one declaration supplies the rendered
    /// title AND the search anchor, so a section is findable by
    /// existing (#277) and its anchor id is stable however the
    /// localized text collides or changes.
    @MainActor init(
        _ control: SettingsControl,
        symbol: String? = nil,
        caption: String? = nil,
        subsection: Bool = false,
        help: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = control.text
        self.control = control
        self.symbol = symbol
        self.caption = caption
        self.subsection = subsection
        self.help = help
        self.content = content()
    }

    var body: some View {
        if let control {
            core.searchAnchorCard(control)
        } else {
            core
        }
    }

    private var core: some View {
        VStack(alignment: .leading, spacing: 8) {
            flashedHeader
            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding(12)
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        Color(
                            nsColor: .controlBackgroundColor
                        )
                    )
            )
        }
        // The hoisted scroll markers (#610): any `scrollHoisted`
        // inline drawer inside `content` publishes its control up
        // `HoistedRevealAnchorsKey`, and each becomes a zero-size
        // marker pinned to the top edge ABOVE the heading — so a
        // reveal of that drawer lands the section's top, heading
        // first, while the drawer's own wash paints below. The id
        // is the drawer's own, so scroll and wash cannot disagree.
        // Then consume the value, so a section nested in another
        // never re-collects the same id and doubles the marker.
        .overlayPreferenceValue(HoistedRevealAnchorsKey.self) {
            anchors in
            revealMarkers(anchors)
        }
        .transformPreference(HoistedRevealAnchorsKey.self) {
            $0 = []
        }
    }

    private func revealMarkers(
        _ anchors: [SettingsControl]
    ) -> some View {
        // Fill the section and top-pin the markers, so this does
        // not lean on `overlayPreferenceValue`'s default centering
        // — the markers must sit at the section's top edge for
        // `scrollTo(anchor: .top)` to land the heading.
        VStack(spacing: 0) {
            ForEach(anchors, id: \.id) { target in
                Color.clear
                    .frame(width: 0, height: 0)
                    .searchScrollAnchor(target)
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .top
        )
        .allowsHitTesting(false)
    }

    /// A catalog-declared section is a search anchor by existing
    /// (#277) — its `SettingsControl` supplies the stable id. The
    /// wash marks the heading; the scroll target is the whole
    /// card (`body`). Both halves read the one `control`, and the
    /// unanchored String init takes neither: an earlier cut
    /// flashed on `anchorID ?? ""`, a sentinel that no reveal can
    /// ever name and that reads as a second, disagreeing id.
    @ViewBuilder private var flashedHeader: some View {
        if let control {
            header.searchFlashHeader(control)
        } else {
            header
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                HStack(spacing: 6) {
                    if let symbol {
                        Image(systemName: symbol)
                            .foregroundStyle(.secondary)
                    }
                    Text(title)
                }
                .font(
                    subsection
                        ? .subheadline.weight(.semibold)
                        : .headline
                )
                if let help {
                    HelpButton(
                        explanation: help,
                        subject: title
                    )
                }
            }
            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
