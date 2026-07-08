import SwiftUI

/// The two-group source list (#68 §3.1). Group headers name
/// the scope split (§0): "This Profile" follows the banner's
/// edit target, "Whole App" is always live state.
struct SettingsSidebar: View {
    @Binding var selection: SettingsDestination
    /// Hides the global-only destinations while a stored
    /// profile is being edited (#18).
    let editingStoredProfile: Bool

    var body: some View {
        List(selection: $selection) {
            Section("Design") {
                ForEach(SettingsDestination.thisProfile) {
                    row($0)
                }
            }
            Section("System") {
                ForEach(visibleWholeApp) { row($0) }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top, spacing: 0) {
            appIdentity
        }
        .navigationSplitViewColumnWidth(
            min: 176,
            ideal: 190,
            max: 240
        )
    }

    /// App identity centered at the top of the sidebar (#68):
    /// colour mark + name, sitting under the traffic lights
    /// where `NavigationSplitView` insets the sidebar top. The
    /// selected section's name rides the titlebar separately,
    /// the System Settings split.
    private var appIdentity: some View {
        HStack(spacing: 8) {
            if let mark = BrandAssets.appMark {
                Image(nsImage: mark)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
            }
            Text("KiwiDesk")
                .font(.title3.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var visibleWholeApp: [SettingsDestination] {
        SettingsDestination.wholeApp.filter {
            $0.isReachable(
                editingStoredProfile: editingStoredProfile
            )
        }
    }

    private func row(
        _ destination: SettingsDestination
    ) -> some View {
        Label {
            Text(destination.title)
        } icon: {
            SidebarTile(destination: destination)
        }
        .tag(destination)
    }
}

/// A System-Settings-style icon tile: white glyph on a flat
/// rounded-rect color (§6.1).
struct SidebarTile: View {
    let destination: SettingsDestination

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(destination.tint)
            .frame(width: 22, height: 22)
            .overlay {
                Image(systemName: destination.symbol)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
            }
    }
}
