import KiwiDeskCore
import SwiftUI

/// The header's release menu (#2308): what it lists, and the
/// selection `WhatsNewBrowser` owns.
struct ReleasePicking {
    let releases: WhatsNewReleases
    let selection: Binding<WhatsNewReleases.Option>
}

/// "What's new" for any listed release: the notes the selection
/// names, in the update window's own layout, reporting each
/// switch so a "Show me" hands off the rows on screen.
struct WhatsNewBrowser: View {
    let menu: WhatsNewMenu
    let narration: BootNarration?
    let next: NextOnMyList?
    let done: () -> Void
    let onShow: (UpdateOffer) -> Void
    @State private var selection: WhatsNewReleases.Option

    init(
        menu: WhatsNewMenu,
        narration: BootNarration?,
        next: NextOnMyList?,
        done: @escaping () -> Void,
        onShow: @escaping (UpdateOffer) -> Void
    ) {
        self.menu = menu
        self.narration = narration
        self.next = next
        self.done = done
        self.onShow = onShow
        _selection = State(initialValue: menu.opening)
    }

    var body: some View {
        UpdateWindowView(
            offer: offer,
            mode: .whatsNew(
                narration: narration,
                next: next,
                picking: ReleasePicking(
                    releases: menu.releases,
                    selection: $selection
                ),
                done: done
            )
        )
        .onChange(of: selection) { onShow(offer) }
    }

    /// Every listed option resolves; the opening is the net.
    private var offer: UpdateOffer {
        menu.releases.offer(for: selection) ?? menu.offer
    }
}

/// The menu itself: a pop-up picker, named for VoiceOver and
/// valued with its choice (#812).
struct ReleasePicker: View {
    let picking: ReleasePicking

    var body: some View {
        Picker(Self.label, selection: picking.selection) {
            ForEach(picking.releases.options, id: \.self) { option in
                Text(Self.title(option, in: picking.releases)).tag(option)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .neutralMenuLabel()
        .fixedSize()
        .accessibilityLabel(Self.label)
        .accessibilityValue(
            Self.title(picking.selection.wrappedValue, in: picking.releases)
        )
    }

    @MainActor static var label: String {
        L("update.window.release_picker", "Release")
    }

    /// "2.3.1 · 12 Oct 2026", the running one marked; the merged
    /// range by the version it starts after.
    @MainActor
    static func title(
        _ option: WhatsNewReleases.Option,
        in releases: WhatsNewReleases
    ) -> String {
        switch option {
        case .since(let start):
            let shown =
                releases.feed.first { $0.version == start }?.shown ?? start
            return L("update.window.release_since", "Since %1$@", shown)
        case .release(let version):
            let item = releases.item(version)
            let shown = item?.shown ?? version
            let dated =
                item?.released.map {
                    L(
                        "update.window.release_option",
                        "%1$@ · %2$@",
                        shown,
                        $0.formatted(date: .abbreviated, time: .omitted)
                    )
                } ?? shown
            guard version == releases.current else { return dated }
            return L(
                "update.window.release_current",
                "%1$@ (this version)",
                dated
            )
        }
    }
}
