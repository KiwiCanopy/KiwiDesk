import KiwiDeskCore
import SwiftUI

/// A bar's Per screen drawer (#1948): one edge picker per screen
/// of the draft profile, each showing the edge that screen gets.
/// A pick of the bar's own edge stores nothing; the drawer opens
/// by itself, held open, while a screen has an edge of its own.
/// Not a `SettingsDisclosure`: its key is a catalog CHILD of Each
/// bar, which search opens, and its rows are dynamic, so a hit
/// lands on this header.
struct ScreenEdgesDrawer<Bar: ScreenEdged>: View {
    @ObservedObject var model: SettingsModel
    let bar: WritableKeyPath<TilingSettings, Bar>
    /// The drawer's title; its catalog child is anchored at the
    /// mount (`.searchAnchored`).
    let title: String
    /// The bar's own name, which VoiceOver hears with the title.
    let barName: String
    let options: [(String, AppBarEdge)]
    @State private var expanded = false

    /// Held open while what it shows differs from the bar.
    private var locked: Bool {
        model.config.settings[keyPath: bar].screensDiffer
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsDisclosureButton(
                isExpanded: $expanded,
                locked: locked,
                isHeading: false
            ) {
                Text(title)
                    .font(.callout)
                    .foregroundStyle(SettingsTheme.ink)
                Spacer(minLength: 0)
            }
            .accessibilityLabel(
                L(
                    "kiwishelf.edge.per_screen.ax",
                    "%1$@, %2$@",
                    barName,
                    title
                )
            )
            if expanded || locked {
                ForEach(model.screenEdgeRows(bar)) { row in
                    screenRow(row)
                }
            }
        }
        .padding(.leading, 14)
    }

    private func screenRow(_ row: ScreenEdgeRow) -> some View {
        // One element per row: the picker speaks the name, the
        // count and the absence; the drawn twins are hidden.
        let name = row.count > 1 ? "\(row.name) × \(row.count)" : row.name
        let absent = L("kiwishelf.edge.screen.absent", "not connected")
        return SettingsRowShape {
            HStack(spacing: 6) {
                Text(name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if !row.present {
                    BadgeChip(label: absent)
                }
            }
            .accessibilityHidden(true)
        } control: {
            SegmentedPicker(
                spokenLabel: row.present
                    ? name
                    : L(
                        "kiwishelf.edge.screen.ax_absent",
                        "%1$@, %2$@",
                        name,
                        absent
                    ),
                selection: model.screenEdge(bar, on: row.id),
                options: options
            )
        }
        .padding(.leading, 16)
    }
}
