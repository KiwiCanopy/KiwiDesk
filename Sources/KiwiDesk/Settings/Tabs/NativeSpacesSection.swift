import KiwiDeskCore
import SwiftUI

/// Canvas tab section (#7): bind a saved profile to each native
/// macOS Space, picked from the row's dropdown; the binding
/// emits `bind_profile_to_native_space` and loads that profile
/// when the Space activates. Rows are named "Desktop n" — the
/// name Mission Control shows — never "Space n", which is how
/// KiwiDesk's own virtual spaces read elsewhere in the app.
/// Bindings mutate `model.config.profileBindings`; the footer's
/// profile actions persist them.
struct NativeSpacesSection: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        SettingsSection("Profiles per macOS Space") {
            if spaceNumbers.isEmpty {
                emptyHint
            } else {
                intro
                ForEach(spaceNumbers, id: \.self) { number in
                    spaceRow(number)
                }
            }
        }
    }

    private var intro: some View {
        Text(
            "Each Desktop is a native macOS Space from "
                + "Mission Control. Pick a profile to load it "
                + "automatically when that Desktop activates."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var emptyHint: some View {
        Text(
            "No native macOS Spaces detected. Enable \u{201C}"
                + "Displays have separate Spaces\u{201D} and add "
                + "desktops in Mission Control to bind profiles."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - Rows

    private func spaceRow(_ number: Int) -> some View {
        HStack {
            Image(systemName: "square.on.square")
                .foregroundStyle(.secondary)
            Text("Desktop \(number)")
                .fontWeight(.medium)
            if number == model.currentNativeSpace {
                BadgeChip(label: "current")
            }
            Spacer()
            profileMenu(number)
        }
    }

    private func profileMenu(_ number: Int) -> some View {
        Picker("", selection: binding(number)) {
            Text("None").tag(String?.none)
            ForEach(options(number), id: \.self) { name in
                Text(name).tag(String?.some(name))
            }
        }
        .labelsHidden()
        .controlSize(.large)
        .frame(width: 180)
    }

    // MARK: - Data

    /// Native Spaces to list: every present desktop plus any
    /// number already bound (so a binding to a now-absent Space
    /// stays visible and editable rather than silently lost).
    private var spaceNumbers: [Int] {
        let present =
            model.nativeSpaceCount > 0
            ? Array(1...model.nativeSpaceCount) : []
        return Array(
            Set(present).union(model.config.profileBindings.keys)
        ).sorted()
    }

    /// Available profiles for the dropdown, always including the
    /// current binding even if its file has since been deleted.
    private func options(_ number: Int) -> [String] {
        var names = model.profiles
        if let bound = model.config.profileBindings[number],
            !names.contains(bound)
        {
            names.append(bound)
        }
        return names
    }

    private func binding(_ number: Int) -> Binding<String?> {
        Binding(
            get: { model.config.profileBindings[number] },
            set: { model.config.profileBindings[number] = $0 }
        )
    }
}
