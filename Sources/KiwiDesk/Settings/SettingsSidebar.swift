import KiwiDeskCore
import SwiftUI

/// The two-group source list (#68 §3.1). Group headers name
/// the scope split (§0): "This Profile" follows the banner's
/// edit target, "Whole App" is always live state.
struct SettingsSidebar: View {
    @Binding var selection: SettingsDestination
    /// Hides the global-only destinations while a stored
    /// profile is being edited (#18).
    let editingStoredProfile: Bool
    /// Swaps the identity mark to the golden variant on dark.
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        List(selection: $selection) {
            Section(L("sidebar.section.design", "Design")) {
                ForEach(SettingsDestination.thisProfile) {
                    row($0)
                }
            }
            Section(L("sidebar.section.system", "System")) {
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
    /// colour mark + name, just under the traffic lights. The
    /// selected section's name rides the titlebar separately,
    /// the System Settings split.
    private var appIdentity: some View {
        HStack(spacing: 8) {
            if let mark {
                Image(nsImage: mark)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
            }
            Text(L("sidebar.app_name", "KiwiDesk"))
                .font(.title3.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 12)
        // Pull the mark up toward the traffic lights: the sidebar
        // otherwise reserves the full empty-toolbar top safe area,
        // leaving a void below the lights. A negative inset seats
        // it just under them — tune -6…-16 if the lights clip.
        .padding(.top, -10)
        .padding(.bottom, 8)
    }

    /// The golden dark mark on dark, colour mark on light;
    /// falls back across variants if one resource is missing.
    private var mark: NSImage? {
        colorScheme == .dark
            ? BrandAssets.appMarkDark ?? BrandAssets.appMark
            : BrandAssets.appMark
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
