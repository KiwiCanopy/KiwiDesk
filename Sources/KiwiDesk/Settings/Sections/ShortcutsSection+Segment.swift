import KiwiDeskCore
import SwiftUI

/// The segmented control over the Shortcuts page (#3184): centred,
/// so it reads apart from Built-in's chips, which start at the
/// leading edge (#1520 amendment 6).
extension ShortcutsSection {
    var segmentControl: some View {
        SegmentedPicker(
            spokenLabel: SettingsDestination.shortcuts.title,
            reservesWeight: true,
            selection: segmentBinding,
            options: ShortcutsSegment.allCases.map { ($0.title, $0) }
        )
        .fixedSize()
        .frame(maxWidth: .infinity)
        .padding(.horizontal, SettingsMetrics.paneInset)
        .padding(.top, 4)
        .padding(.bottom, segment == .builtIn ? 0 : 10)
    }

    /// The user's pick. Only this write arms Mouse & Trackpad's
    /// first picture, once per visit; a search or Go to lands on
    /// the part through `nav` and plays nothing.
    private var segmentBinding: Binding<ShortcutsSegment> {
        Binding(
            get: { segment },
            set: { picked in
                if picked == .mouse, !gesturesPlayed {
                    gesturesPlayed = true
                    gesturesPlay = true
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
    /// links to it.
    var shortcutsSegment: ShortcutsSegment? {
        get { self[ShortcutsSegmentKey.self] }
        set { self[ShortcutsSegmentKey.self] = newValue }
    }
}
