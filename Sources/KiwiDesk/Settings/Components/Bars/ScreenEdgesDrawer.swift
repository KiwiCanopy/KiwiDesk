import KiwiDeskCore
import SwiftUI

/// A bar's Per screen drawer (#1948): one edge picker per screen
/// of the draft profile, each showing the edge that screen gets.
/// A pick of the bar's own edge stores nothing; the drawer opens
/// by itself, held open, while a screen has an edge of its own.
struct ScreenEdgesDrawer<Bar: ScreenEdged>: View {
    @ObservedObject var model: SettingsModel
    let bar: WritableKeyPath<TilingSettings, Bar>
    /// The drawer's title; its catalog child is anchored at the
    /// mount (`.searchAnchored`).
    let title: String
    let options: [(String, AppBarEdge)]
    @State private var expanded = false

    /// Held open while what it shows differs from the bar.
    private var locked: Bool {
        model.config.settings[keyPath: bar].screensDiffer
    }

    private var expansion: Binding<Bool> {
        Binding(
            get: { expanded || locked },
            set: { expanded = $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsDisclosureButton(
                isExpanded: expansion,
                locked: locked,
                isHeading: false
            ) {
                Text(title)
                    .font(.callout)
                    .foregroundStyle(SettingsTheme.ink)
                Spacer(minLength: 0)
            }
            if expansion.wrappedValue {
                ForEach(model.screenEdgeRows) { row in
                    screenRow(row)
                }
            }
        }
        .padding(.leading, 14)
    }

    private func screenRow(_ row: ScreenEdgeRow) -> some View {
        SettingsRowShape {
            HStack(spacing: 6) {
                Text(row.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .accessibilityHidden(true)
                if row.count > 1 {
                    Text(
                        L(
                            "kiwishelf.edge.screen.count",
                            "Screens: %1$d",
                            row.count
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.ink3)
                }
                if !row.present {
                    BadgeChip(
                        label: L(
                            "kiwishelf.edge.screen.absent",
                            "not present"
                        )
                    )
                }
            }
        } control: {
            SegmentedPicker(
                spokenLabel: row.name,
                selection: model.screenEdge(bar, on: row.id),
                options: options
            )
        }
        .padding(.leading, 16)
    }
}
