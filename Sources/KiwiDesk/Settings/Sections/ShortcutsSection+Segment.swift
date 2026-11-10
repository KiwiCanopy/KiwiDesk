import KiwiDeskCore
import SwiftUI

/// The segmented control over the Shortcuts page (#3184): centred,
/// so it reads apart from Built-in's chips, which start at the
/// leading edge (#1520 amendment 6).
extension ShortcutsSection {
    func segmentControl(_ proxy: ScrollViewProxy) -> some View {
        SegmentedPicker(
            spokenLabel: SettingsDestination.shortcuts.title,
            reservesWeight: true,
            selection: segmentBinding(proxy),
            options: ShortcutsSegment.allCases.map { ($0.title, $0) }
        )
        .fixedSize()
        .frame(maxWidth: .infinity)
        .padding(.horizontal, SettingsMetrics.paneInset)
        .padding(.top, 4)
        .padding(.bottom, segment == .builtIn ? 0 : 10)
    }

    /// The user's pick, which opens the part at its top: the page's
    /// one scroll view is kept across parts, so the offset would
    /// carry over. Only this write arms Mouse & Trackpad's first
    /// picture, once per visit; a search or Go to lands on the part
    /// through `nav` and plays nothing.
    private func segmentBinding(
        _ proxy: ScrollViewProxy
    ) -> Binding<ShortcutsSegment> {
        Binding(
            get: { segment },
            set: { picked in
                guard picked != segment else { return }
                if picked == .mouse, !gesturesPlayed {
                    gesturesPlayed = true
                    gesturesPlay = true
                }
                if let top = ShortcutsPagePart.parts(in: segment).first {
                    proxy.scrollTo(top.id, anchor: .top)
                }
                model.nav.shortcutsSegment = picked
            }
        )
    }
}

private struct ShortcutsSegmentKey: EnvironmentKey {
    static let defaultValue: ShortcutsSegment? = nil
}

extension EnvironmentValues {
    /// The Shortcuts page's part a row is drawn in, nil off that
    /// page (#3184): a conflict naming a row of the other part
    /// links to it (`RecorderCoordinator.segmentHolding`).
    var shortcutsSegment: ShortcutsSegment? {
        get { self[ShortcutsSegmentKey.self] }
        set { self[ShortcutsSegmentKey.self] = newValue }
    }
}
