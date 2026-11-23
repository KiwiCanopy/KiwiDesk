import KiwiDeskCore
import SwiftUI

/// A bar's Per screen drawer (#1948): one edge picker per screen
/// of the draft profile, each showing the edge that screen gets —
/// per area on a split screen — and for the two bars a Show menu
/// beside it, that screen's or area's visibility (#3517 ruling 30).
/// A pick of the bar's own edge stores nothing; the drawer opens
/// by itself, held open, while a screen has an edge or a Show of
/// its own. On a one-screen profile with no split its rows grey,
/// its `?` naming what unlocks them (#2677).
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
    /// The bar a row's Show menu writes; nil draws edges alone.
    var show: ScreenShowBar? = nil
    @State private var expanded = false

    /// Whether the profile has screens or areas to tell apart.
    private var offered: Bool { model.offersScreenEdges(bar, show: show) }

    /// Held open while what it shows differs from the bar.
    private var locked: Bool {
        model.config.settings[keyPath: bar].screensDiffer
            || show.map(model.hasScreenShows) == true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // The `?` follows the label, so the header takes only
            // its own width.
            HStack(spacing: 6) {
                header.fixedSize()
                if !offered {
                    HelpButton(
                        explanation: Self.oneScreenHelp,
                        subject: spokenTitle
                    )
                }
                Spacer(minLength: 0)
            }
            // The label stays live and only the rows grey (#527).
            if expanded || locked {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(model.screenEdgeRows(bar, show: show)) { row in
                        screenRow(row)
                    }
                }
                .modifier(GreyOut(active: !offered))
            }
        }
        .padding(.leading, 14)
    }

    private var header: some View {
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
        .accessibilityLabel(spokenTitle)
    }

    /// The drawer's name with its bar's, which both drawers need.
    private var spokenTitle: String {
        L(
            "kiwishelf.edge.per_screen.ax",
            "%1$@, %2$@",
            barName,
            title
        )
    }

    static var oneScreenHelp: String {
        L(
            "kiwishelf.edge.per_screen.one_screen_or_split",
            "Needs a profile with two or more screens, or a screen "
                + "split into areas."
        )
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
            let spoken =
                row.present
                ? name
                : L(
                    "kiwishelf.edge.screen.ax_absent",
                    "%1$@, %2$@",
                    name,
                    absent
                )
            HStack(spacing: 8) {
                SegmentedPicker(
                    spokenLabel: show == nil
                        ? spoken
                        : Self.qualified(
                            spoken,
                            L("kiwishelf.edge.label", "Position")
                        ),
                    selection: model.screenEdge(bar, on: row.id),
                    options: options
                )
                if let show {
                    showMenu(show, row: row, spoken: spoken)
                }
            }
        }
        .padding(.leading, 16)
    }

    /// The row's Show menu: Always, Auto or Hidden, and for the App
    /// Bar Per layout, which follows each layout's own.
    private func showMenu(
        _ show: ScreenShowBar,
        row: ScreenEdgeRow,
        spoken: String
    ) -> some View {
        let options = SettingsModel.screenShowOptions(show)
        let value = model.screenShow(show, on: row.id)
        let title = options.first { $0.0 == value }?.1 ?? ""
        return Picker(
            selection: model.screenShowBinding(show, on: row.id)
        ) {
            ForEach(options, id: \.1) { option in
                Text(option.1).tag(option.0)
            }
        } label: {
            EmptyView()
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .neutralMenuLabel()
        .fixedSize()
        .accessibilityLabel(
            Self.qualified(spoken, L("kiwishelf.show.label", "Show"))
        )
        .accessibilityValue(title)
    }

    /// A row's name with the control it names, so its two controls
    /// speak apart.
    private static func qualified(_ name: String, _ control: String) -> String
    {
        L("kiwishelf.per_screen.control.ax", "%1$@, %2$@", name, control)
    }
}
