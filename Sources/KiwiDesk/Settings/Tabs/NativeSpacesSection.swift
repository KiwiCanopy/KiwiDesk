import KiwiDeskCore
import SwiftUI

/// Canvas tab section (#7): bind a saved profile to each native
/// macOS Space. Drag a profile chip onto a Space or pick from the
/// dropdown; the binding emits `bind_profile_to_native_space` and
/// loads that profile when the Space activates. Bindings mutate
/// `model.config.profileBindings`; the footer Save persists them.
struct NativeSpacesSection: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        SettingsSection("Profiles per macOS Space") {
            if spaceNumbers.isEmpty {
                emptyHint
            } else {
                intro
                if !model.profiles.isEmpty { palette }
                ForEach(spaceNumbers, id: \.self) { number in
                    spaceRow(number)
                }
            }
        }
    }

    private var intro: some View {
        Text(
            "Drag a profile onto a Space (or pick one) to load "
                + "it automatically when that Space activates."
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

    private var palette: some View {
        WrapChips(model.profiles) { name in
            ProfileChip(name: name)
                .draggable(DraggableProfile(name: name))
        }
    }

    // MARK: - Rows

    private func spaceRow(_ number: Int) -> some View {
        HStack {
            Image(systemName: "square.on.square")
                .foregroundStyle(.secondary)
            Text("Space \(number)")
                .fontWeight(.medium)
            if number == model.currentNativeSpace {
                Text("current")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.tint.opacity(0.15)))
            }
            Spacer()
            profileMenu(number)
        }
        .dropDestination(for: DraggableProfile.self) {
            items,
            _ in
            guard let name = items.first?.name else {
                return false
            }
            model.config.profileBindings[number] = name
            return true
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

/// A pill rendering a profile name, draggable onto a Space row.
struct ProfileChip: View {
    let name: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "rectangle.stack")
                .font(.caption2)
            Text(name)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(.tint.opacity(0.15)))
        .overlay(Capsule().strokeBorder(.tint.opacity(0.4)))
    }
}
