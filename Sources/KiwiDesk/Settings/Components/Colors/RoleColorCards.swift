import KiwiDeskCore
import SwiftUI

/// The two role groups that open Advanced Colours, side by side,
/// stacked where the window's rows stack (#1857): the halves of
/// each colour-vision pair are read together.
struct RoleColorCards: View {
    @ObservedObject var model: SettingsModel
    @Environment(\.settingsWidth) private var width

    var body: some View {
        let layout =
            width.stacksRows
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 20))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
        layout {
            ForEach(ColorRole.allCases, id: \.self) { role in
                RoleColorCard(model: model, role: role)
            }
        }
    }
}

/// One role group: its colour, its rows — each greyed by its
/// verdict and ticked into the colour or not — and a live link
/// beneath for each reason (#1310).
struct RoleColorCard: View {
    @ObservedObject var model: SettingsModel
    let role: ColorRole
    /// Which rows the colour writes; scratch, never stored, seeded
    /// each time the page appears (`RolePaint.seed`).
    @State private var ticked: Set<SettingKey>?

    private var gates: AdvancedColorsGates {
        AdvancedColorsGates(settings: model.config.settings)
    }

    private var paint: RolePaint {
        RolePaint(
            role: role,
            settings: model.config.settings,
            ticked: ticked ?? [],
            dimmed: Set(role.keys.filter { gates.verdict(for: $0) != nil })
        )
    }

    var body: some View {
        SettingsSection(role.control, caption: role.caption) {
            RolePaintRow(role: role, paint: paint, hex: wellHex)
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                ForEach(role.keys, id: \.id) { key in
                    row(key)
                }
            }
            if role.keys.contains(.spaceBar(.spaceBarFocusedItemColor)),
                gates.needsOwnSentence(.spaceBar(.spaceBarFocusedItemColor))
            {
                CrossReferenceRow(
                    prose: AdvancedColorsHelp.focusedItemReference,
                    linkTitle: SettingsDestination.bars.title,
                    destination: .bars
                )
            }
            ForEach(
                gates.dimmedDestinations(of: role.keys),
                id: \.self
            ) { destination in
                CrossReferenceRow(
                    prose: AdvancedColorsHelp.dimmedReference,
                    linkTitle: destination.title,
                    destination: destination
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            ticked = RolePaint.seed(role, model.config.settings)
        }
    }

    private var wellHex: Binding<String> {
        Binding(
            get: { paint.wellHex },
            set: { model.config.settings = paint.painted($0) }
        )
    }

    private func row(_ key: SettingKey) -> some View {
        let verdict = gates.verdict(for: key)
        return HStack(spacing: 6) {
            RoleTickBox(
                role: role,
                key: key,
                tickable: paint.tickable(key),
                isOn: tick(key)
            )
            AdvancedColorRow(model: model, key: key)
        }
        .modifier(
            GreyOut(active: verdict != nil, help: verdict?.help ?? "")
        )
    }

    private func tick(_ key: SettingKey) -> Binding<Bool> {
        Binding(
            get: { ticked?.contains(key) ?? false },
            set: { on in
                var set = ticked ?? []
                if on { set.insert(key) } else { set.remove(key) }
                ticked = set
            }
        )
    }
}
