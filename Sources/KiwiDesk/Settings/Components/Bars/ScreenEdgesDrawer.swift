import KiwiDeskCore
import SwiftUI

/// A bar's Per screen or area drawer (#1948, #3612): one row per
/// screen of the draft profile — per area on a split screen — each
/// named as Settings ▸ Screens names it, its labelled Show strip
/// (the two bars only, #3517 ruling 30) stacked over its Position
/// strip. A pick of the bar's own value stores nothing; the drawer
/// opens by itself, held open, while a screen has an edge or a Show
/// of its own. On a one-screen profile with no split its rows grey,
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
        // The name line is drawn; each strip speaks the name with
        // its own control, and the absence.
        let name = row.count > 1 ? "\(row.name) × \(row.count)" : row.name
        let absent = L("kiwishelf.edge.screen.absent", "not connected")
        let spoken =
            row.present
            ? name
            : L(
                "kiwishelf.edge.screen.ax_absent",
                "%1$@, %2$@",
                name,
                absent
            )
        let position = L("kiwishelf.edge.label", "Position")
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(name)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if !row.present {
                    BadgeChip(label: absent)
                }
            }
            .accessibilityHidden(true)
            if let show {
                showStrip(show, row: row, spoken: spoken)
            }
            labelled(position) {
                SegmentedPicker(
                    spokenLabel: Self.qualified(spoken, position),
                    selection: model.screenEdge(bar, on: row.id),
                    options: options
                )
            }
        }
        .padding(.leading, 16)
    }

    /// The row's Show strip: Always, Auto or Hidden, and for the App
    /// Bar Per layout first, which follows each layout's own.
    private func showStrip(
        _ show: ScreenShowBar,
        row: ScreenEdgeRow,
        spoken: String
    ) -> some View {
        let label = L("kiwishelf.show.label", "Show")
        return labelled(label) {
            SegmentedPicker(
                spokenLabel: Self.qualified(spoken, label),
                selection: model.screenShowBinding(show, on: row.id),
                options: SettingsModel.screenShowOptions(show)
                    .map { ($0.1, $0.0) }
            )
        }
    }

    /// A strip on the label axis, its drawn label silent: the strip
    /// speaks the row's name with it.
    private func labelled<Control: View>(
        _ label: String,
        @ViewBuilder control: () -> Control
    ) -> some View {
        SettingsRowShape {
            SettingsRowLabel(label: label)
        } control: {
            control()
        }
    }

    /// A row's name with the control it names, so its two controls
    /// speak apart.
    private static func qualified(_ name: String, _ control: String) -> String
    {
        L("kiwishelf.per_screen.control.ax", "%1$@, %2$@", name, control)
    }
}
