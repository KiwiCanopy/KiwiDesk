import KiwiDeskCore
import SwiftUI

/// The notes between the pinned header and footer: a pinned tab
/// strip over one scrolling list — Highlights, one type's
/// changes (#1666 ruling), or "Next on my list" (#1849).
struct UpdateNotesScroll: View {
    let offer: UpdateOffer
    /// The Failed state steps the Highlights gold back.
    let failed: Bool
    /// After the update: the cautions are past advice.
    let whatsNew: Bool
    /// The last tab's list, while there is one.
    var next: NextOnMyList?
    /// Lays every tab out at once, unscrolled, so the window's
    /// height is the tallest tab's and a switch does not jump it.
    let measuring: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selection: UpdateNotesTab
    @State private var moreBelow = false

    init(
        offer: UpdateOffer,
        failed: Bool,
        whatsNew: Bool,
        next: NextOnMyList? = nil,
        opening: UpdateNotesTab = UpdateNotesTabs.initial,
        measuring: Bool
    ) {
        self.offer = offer
        self.failed = failed
        self.whatsNew = whatsNew
        self.next = next
        self.measuring = measuring
        _selection = State(initialValue: opening)
    }

    private var tabs: [UpdateNotesTab] {
        UpdateNotesTabs.tabs(offer.digest, next: next != nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            if tabs.count > 1 {
                UpdateNotesTabStrip(
                    digest: offer.digest,
                    next: next != nil,
                    selection: $selection
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, UpdateWindowMetrics.inset)
                .padding(.bottom, 14)
            }
            if measuring {
                padded
            } else {
                ScrollView { padded }
                    // A switch opens the new tab at its top.
                    .id(selection)
                    .modifier(UpdateNotesScrollCues(moreBelow: $moreBelow))
                    .mask { fade }
            }
        }
    }

    private var padded: some View {
        content
            .padding(.horizontal, UpdateWindowMetrics.inset)
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .tint(SettingsTheme.ink)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            if measuring {
                ZStack(alignment: .topLeading) {
                    ForEach(tabs, id: \.self) { pane($0) }
                }
            } else {
                pane(selection)
            }
            if measuring || selection != .next { links }
        }
    }

    @ViewBuilder
    private func pane(_ tab: UpdateNotesTab) -> some View {
        switch tab {
        case .highlights:
            if let digest = offer.digest {
                UpdateHighlightsPanel(
                    digest: digest,
                    failed: failed,
                    whatsNew: whatsNew
                )
            } else {
                Text(
                    L(
                        "update.window.no_notes",
                        "This version's notes are online."
                    )
                )
                .foregroundStyle(SettingsTheme.ink2)
                .updateNotesCard()
            }
        case .group(let id):
            if let group = offer.digest?.group(id) {
                UpdateNotesGroupList(
                    group: group,
                    labelled: offer.digest?.spansVersions ?? false
                )
            }
        case .next:
            if let next {
                // After the update or with none: the offer asks
                // nothing beside its Install (#1849).
                NextOnMyListPanel(next: next, asksForSupport: whatsNew)
            }
        }
    }

    /// The notes' own links: a version whose notes do not read,
    /// and the full notes online.
    @ViewBuilder private var links: some View {
        ForEach(offer.digest?.unreadable ?? [], id: \.self) { version in
            UpdateNotesLink(
                title: L(
                    "update.window.version_notes",
                    "Release notes for %1$@",
                    version
                ),
                url: UpdateOffer.notesURL(for: version)
            )
        }
        UpdateNotesLink(
            title: L("update.window.full_notes", "Full release notes"),
            url: UpdateOffer.notesURL(for: offer.version)
        )
    }

    /// Soft edge while more is below (#1542 ruling): the notes
    /// themselves fade, since a painted band would show on glass
    /// (#1849).
    private var fade: some View {
        // A mask reads alpha alone; `.primary` is any opaque ink.
        VStack(spacing: 0) {
            Rectangle().fill(.primary)
            LinearGradient(
                colors: [.primary, .primary.opacity(moreBelow ? 0 : 1)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 34)
        }
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.2),
            value: moreBelow
        )
    }
}

/// The scroller flashes on open and the fade tracks what is below
/// — both macOS 15 APIs; macOS 14 keeps the plain scroller.
private struct UpdateNotesScrollCues: ViewModifier {
    @Binding var moreBelow: Bool

    func body(content: Content) -> some View {
        if #available(macOS 15, *) {
            content
                .scrollIndicatorsFlash(onAppear: true)
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.contentSize.height
                        - geometry.contentOffset.y
                        - geometry.containerSize.height > 4
                } action: { _, below in
                    moreBelow = below
                }
        } else {
            content
        }
    }
}

/// A plain underlined link in the window's secondary ink.
struct UpdateNotesLink: View {
    let title: String
    let url: URL

    var body: some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            Text(title)
                .underline()
                .font(.system(size: 12.5))
                .foregroundStyle(SettingsTheme.ink2)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isLink)
        .pointingHandCursor()
    }
}
