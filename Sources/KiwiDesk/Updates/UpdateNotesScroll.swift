import KiwiDeskCore
import SwiftUI

/// The notes between the pinned header and footer: Highlights,
/// then every change grouped by type (#1542 ruling ▸ Window).
struct UpdateNotesScroll: View {
    let offer: UpdateOffer
    /// The Failed state steps the Highlights gold back.
    let failed: Bool
    let measuring: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var open: Set<String>
    @State private var expanded: Set<String> = []
    @State private var moreBelow = false

    init(offer: UpdateOffer, failed: Bool, measuring: Bool) {
        self.offer = offer
        self.failed = failed
        self.measuring = measuring
        _open = State(
            initialValue: UpdateNotesDisclosure.initiallyOpen(
                offer.digest?.groups ?? []
            )
        )
    }

    var body: some View {
        ScrollViewReader { proxy in
            if measuring {
                padded(proxy)
            } else {
                ScrollView { padded(proxy) }
                    .modifier(UpdateNotesScrollCues(moreBelow: $moreBelow))
            }
        }
        .overlay(alignment: .bottom) { fade }
    }

    private func padded(_ proxy: ScrollViewProxy) -> some View {
        content(proxy)
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .tint(SettingsTheme.ink)
    }

    @ViewBuilder
    private func content(_ proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let digest = offer.digest {
                UpdateHighlightsPanel(digest: digest, failed: failed)
                UpdateNotesTally(digest: digest) { jump(to: $0, proxy) }
                ForEach(digest.groups) { group in
                    UpdateNotesGroupCard(
                        group: group,
                        labelled: digest.spansVersions,
                        open: binding(open: group.id),
                        expanded: binding(expanded: group.id)
                    )
                    .id(group.id)
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
                        "This version's notes are on the KiwiDesk site."
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

    /// A per-type link opens its group and scrolls to it.
    private func jump(to id: String, _ proxy: ScrollViewProxy) {
        open.insert(id)
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
            proxy.scrollTo(id, anchor: .top)
        }
    }

    private func binding(open id: String) -> Binding<Bool> {
        Binding(
            get: { open.contains(id) },
            set: { if $0 { open.insert(id) } else { open.remove(id) } }
        )
    }

    private func binding(expanded id: String) -> Binding<Bool> {
        Binding(
            get: { expanded.contains(id) },
            set: { if $0 { expanded.insert(id) } }
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
