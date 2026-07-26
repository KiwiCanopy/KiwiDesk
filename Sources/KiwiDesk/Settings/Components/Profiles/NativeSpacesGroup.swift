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
struct NativeSpacesGroup: View {
    @ObservedObject var model: SettingsModel
    /// Whether the group is read-only, and the explanation to
    /// show while it is. Taken as parameters rather than letting
    /// the caller wrap this whole view in a `GreyOut`: the gate
    /// has to skip the section header so its `?` anchor stays
    /// clickable (#527) — wrapping from outside would disable
    /// the one affordance that says why the rows are dimmed.
    var gatedOff: Bool = false
    var gateHelp: String = ""

    var body: some View {
        SettingsSection(
            L(
                "native_spaces.title",
                "Profiles per macOS Space"
            ),
            // The empty-string guard keeps a caller that gates
            // without copy from rendering a live `?` over an
            // empty popover — no anchor is better than a blank
            // one.
            help: gatedOff && !gateHelp.isEmpty ? gateHelp : nil
        ) {
            // The warning and its "Open Desktop & Dock
            // Settings" button stay OUTSIDE the gate (#527
            // follow-ups): the display-config advice holds — and
            // the button works — whichever profile is being
            // edited. Only the binding rows are read-only here.
            if DisplaySpacesSetting.recommendsSharedSpaces(
                displayCount: model.displays.count
            ) {
                separateSpacesWarning
            }
            Group {
                if spaceNumbers.isEmpty {
                    emptyHint
                } else {
                    intro
                    ForEach(
                        spaceNumbers,
                        id: \.self
                    ) { number in
                        spaceRow(number)
                    }
                }
            }
            .modifier(
                GreyOut(active: gatedOff, help: gateHelp)
            )
        }
    }

    private var separateSpacesWarning: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 8) {
                Text(
                    L(
                        "native_spaces.separate_warning",
                        "Separate display Spaces are on. "
                            + "KiwiDesk uses one active profile "
                            + "across all displays, so Desktop "
                            + "bindings may be ambiguous."
                    )
                )
                .font(.callout)
                Button(
                    L(
                        "native_spaces.open_settings",
                        "Open Desktop & Dock Settings"
                    )
                ) {
                    DisplaySpacesSetting.openSystemSettings()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.12))
        )
    }

    private var intro: some View {
        Text(
            L(
                "native_spaces.intro",
                "Each Desktop is a native macOS Space from "
                    + "Mission Control. Pick a profile to load "
                    + "it automatically when that Desktop "
                    + "activates."
            )
        )
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var emptyHint: some View {
        Text(
            L(
                "native_spaces.empty",
                "No native macOS Desktops detected. Add "
                    + "desktops in Mission Control to bind "
                    + "profiles."
            )
        )
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - Rows

    private func spaceRow(_ number: Int) -> some View {
        HStack {
            Image(systemName: "square.on.square")
                .foregroundStyle(.secondary)
            Text(
                L(
                    "native_spaces.desktop",
                    "Desktop %1$d",
                    number
                )
            )
            .fontWeight(.medium)
            if number == model.currentNativeSpace {
                BadgeChip(
                    label: L("native_spaces.current", "current")
                )
            }
            Spacer()
            profileMenu(number)
        }
    }

    private func profileMenu(_ number: Int) -> some View {
        Picker("", selection: binding(number)) {
            Text(L("native_spaces.none", "None"))
                .tag(String?.none)
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
