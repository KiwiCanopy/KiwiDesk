import KiwiDeskCore
import SwiftUI

/// The segmented control over the Shortcuts page (#3184): centred,
/// so it reads apart from Built-in's chips, which start at the
/// leading edge (#1520 amendment 6).
extension ShortcutsSection {
    /// The page-wide layer pick above the switcher (#3535 ▸ Ruling
    /// 3): every part below it is the picked layer's, so it stays
    /// put across the three. Drawn once a layer other than `default`
    /// exists; until then Personal's Layers card holds the offer.
    @ViewBuilder var layerStrip: some View {
        if ShortcutsGates(config: model.config).layersExist {
            LayerStripEditor(model: model, selected: selection)
                .padding(.horizontal, SettingsMetrics.paneInset)
                .padding(.top, 10)
                .padding(.bottom, 6)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(
                    SettingsCatalog.shortcuts.layersCard.control.text
                )
        }
    }

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
    /// carry over.
    private func segmentBinding(
        _ proxy: ScrollViewProxy
    ) -> Binding<ShortcutsSegment> {
        Binding(
            get: { segment },
            set: { picked in
                guard picked != segment else { return }
                proxy.scrollTo(Self.pageTop, anchor: .top)
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
    /// links to it (`RecorderCoordinator.segmentHolding`), and
    /// `LayersCard` draws open on `.personal` alone, nil taking
    /// Built-in's collapsible shape.
    var shortcutsSegment: ShortcutsSegment? {
        get { self[ShortcutsSegmentKey.self] }
        set { self[ShortcutsSegmentKey.self] = newValue }
    }
}
