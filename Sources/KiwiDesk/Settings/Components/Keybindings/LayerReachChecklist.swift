import KiwiDeskCore
import SwiftUI

/// A layer's "Applies to" popover (#2022), shaped like
/// `RuleReachChecklist`: All profiles, then one box per profile.
/// A tick is membership — unticking a profile takes the layer out
/// of it at Save, under All profiles too, where it is left out and
/// a profile created later still gets it. The edited profile is
/// ticked and locked.
struct LayerReachChecklist: View {
    @ObservedObject var model: SettingsModel
    let layer: String

    var body: some View {
        if let reading = model.layerReach(layer) {
            content(reading)
                .padding(12)
                .frame(minWidth: 260, alignment: .leading)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(LayerReachWords.caption(layer))
        }
    }

    private func content(_ reading: RuleReachReading) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LayerReachWords.caption(layer))
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink3)
            allProfiles(reading)
            Divider()
            ForEach(reading.profiles, id: \.self) { profile in
                profileRow(profile, reading)
            }
            ForEach(reading.unreadable, id: \.self) { profile in
                Toggle(profile, isOn: .constant(false))
                    .toggleStyle(.checkbox)
                    .disabled(true)
                caption(
                    L(
                        "app_rules.reach.unreadable",
                        "⚠ Can't be read — see %1$@.",
                        SettingsDestination.profiles.title
                    ),
                    warning: true
                )
            }
        }
    }

    private func allProfiles(_ reading: RuleReachReading) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Toggle(
                RuleReachWords.allProfiles,
                isOn: Binding(
                    get: { reading.shared },
                    set: { model.setLayerAllProfiles(layer, $0) }
                )
            )
            .toggleStyle(.checkbox)
            caption(
                L(
                    "app_rules.reach.all_caption",
                    "Includes profiles you create later."
                ),
                warning: false
            )
        }
    }

    private func profileRow(
        _ profile: String,
        _ reading: RuleReachReading
    ) -> some View {
        let locked = reading.isLocked(profile)
        return VStack(alignment: .leading, spacing: 1) {
            Toggle(
                isOn: Binding(
                    get: { reading.users.contains(profile) },
                    set: { model.setLayerProfile(layer, profile, $0) }
                )
            ) {
                HStack(spacing: 4) {
                    Text(profile)
                    if let mark = RuleReachWords.mark(profile, reading) {
                        Text(mark).foregroundStyle(SettingsTheme.ink3)
                    }
                }
            }
            .toggleStyle(.checkbox)
            .disabled(locked)
            .help(
                locked
                    ? L(
                        "shortcuts.layer_reach.locked_help",
                        "You're editing this profile. To take the layer "
                            + "out of it, use %1$@.",
                        L("shortcuts.delete_layer", "Delete layer")
                    )
                    : ""
            )
            if reading.leftOut.contains(profile) {
                caption(LayerReachWords.leftOut, warning: true)
            } else if let own = reading.own[profile] {
                caption(own, warning: true)
            }
        }
    }

    private func caption(_ text: String, warning: Bool) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(
                warning ? SettingsTheme.warningInk : SettingsTheme.ink3
            )
            .padding(.leading, 20)
    }
}
