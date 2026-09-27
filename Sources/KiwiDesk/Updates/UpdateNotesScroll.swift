import KiwiDeskCore
import SwiftUI

/// The notes between the pinned header and footer: a pinned tab
/// strip over one scrolling list — Highlights, or one type's
/// changes (#1666 ruling).
struct UpdateNotesScroll: View {
    let offer: UpdateOffer
    /// The Failed state steps the Highlights gold back.
    let failed: Bool
    /// After the update: the cautions are past advice.
    let whatsNew: Bool
    /// Lays every tab out at once, unscrolled, so the window's
    /// height is the tallest tab's and a switch does not jump it.
    let measuring: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selection = UpdateNotesTabs.initial
    @State private var moreBelow = false

    var body: some View {
        VStack(spacing: 0) {
            if let digest = offer.digest,
                UpdateNotesTabs.tabs(digest).count > 1
            {
                UpdateNotesTabStrip(digest: digest, selection: $selection)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)
            }
            if measuring {
                padded
            } else {
                ScrollView { padded }
                    // A switch opens the new tab at its top.
                    .id(selection)
                    .modifier(UpdateNotesScrollCues(moreBelow: $moreBelow))
                    .overlay(alignment: .bottom) { fade }
            }
        }
    }

    private var padded: some View {
        content
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .tint(SettingsTheme.ink)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let digest = offer.digest {
                if measuring {
                    ZStack(alignment: .topLeading) {
                        ForEach(UpdateNotesTabs.tabs(digest), id: \.self) {
                            tab($0, digest)
                        }
                    }
                } else {
                    tab(selection, digest)
                }
                ForEach(digest.unreadable, id: \.self) { version in
                    UpdateNotesLink(
                        title: L(
                            "update.window.version_notes",
                            "Release notes for %1$@",
                            version
                        ),
                        url: UpdateOffer.notesURL(for: version)
                    )
                }
            } else {
                Text(
                    L(
                        "update.window.no_notes",
                        "This version's notes are online."
                    )
                )
                .foregroundStyle(SettingsTheme.ink2)
                .padding(.top, 6)
            }
            UpdateNotesLink(
                title: L("update.window.full_notes", "Full release notes"),
                url: UpdateOffer.notesURL(for: offer.version)
            )
        }
    }

    @ViewBuilder
    private func tab(
        _ tab: UpdateNotesTab,
        _ digest: UpdateNotesDigest
    ) -> some View {
        switch tab {
        case .highlights:
            UpdateHighlightsPanel(
                digest: digest,
                failed: failed,
                whatsNew: whatsNew
            )
        case .group(let id):
            if let group = digest.groups.first(where: { $0.id == id }) {
                UpdateNotesGroupList(
                    group: group,
                    labelled: digest.spansVersions
                )
            }
        }
    }

    /// Soft edge while more is below (#1542 ruling).
    private var fade: some View {
        LinearGradient(
            colors: [SettingsTheme.page.opacity(0), SettingsTheme.page],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 34)
        .opacity(moreBelow ? 1 : 0)
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.2),
            value: moreBelow
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
