import KiwiDeskCore
import SwiftUI

/// KiwiVision ▸ Never dimmed (#2103 rulings 26–27): the apps whose
/// windows KiwiVision never dims or blurs, focused or not. A row is
/// an app's bundle id, or its process name where it has none
/// (SketchyBar); the add picker leads with what is on screen now.
struct KiwiVisionNeverDimmedCard: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        SettingsSection(
            SettingsCatalog.kiwiVision.neverDimmedCard,
            caption: KiwiVisionCopy.appliesAtOnce,
            help: Self.help
        ) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(KiwiVisionRowOrder.neverDimmed, id: \.id) { key in
                    row(key)
                    if let reason {
                        KiwiVisionCopy.reason(
                            KiwiVisionGates.sentence(for: reason)
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder private func row(_ key: SettingKey) -> some View {
        switch key {
        case .kiwiVision(.neverDimmed): list
        default:
            let _ = assertionFailure(
                "unrendered KiwiVision census key: \(key.id)"
            )
            EmptyView()
        }
    }

    private var reason: KiwiVisionGates.InertReason? {
        KiwiVisionGates(guiManaged: model.guiManaged)
            .inertReason(for: .kiwiVision(.neverDimmed))
    }

    private var apps: [String] { model.appWide.visionNeverDimmed }

    private var list: some View {
        VStack(alignment: .leading, spacing: 6) {
            if apps.isEmpty {
                Text(Self.empty)
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(apps, id: \.self) { app in
                HStack(spacing: 6) {
                    AppPickerRowLabel(key: app)
                    Spacer(minLength: 0)
                    AppRuleDeleteButton(help: Self.removeHelp) { _ in
                        set(apps.filter { $0 != app })
                    }
                }
                Divider()
            }
            AppPickerButton(
                placeholder: Self.addLabel,
                selection: nil,
                onPick: { add($0.bundleID) },
                escapeLabel: L("shortcuts.other_ellipsis", "Other…"),
                onEscape: {
                    if let app = AppBundlePanel.pick() { add(app.bundleID) }
                },
                exclude: Set(apps),
                onScreen: { model.core.appsOnScreen() }
            )
            .fixedSize()
            .accessibilityLabel(SettingsCatalog.kiwiVision.neverDimmed.text)
            .accessibilityValue(Self.addLabel)
        }
        .disabled(reason != nil)
        .searchAnchored(SettingsCatalog.kiwiVision.neverDimmed)
    }

    private func add(_ key: String) {
        set(apps + [key])
    }

    private func set(_ list: [String]) {
        model.setAppWide {
            $0.visionNeverDimmed = AppWideSettings.neverDimmedEntries(list)
        }
    }

    static var addLabel: String {
        L("kiwivision.never_dimmed.add", "Add an app…")
    }

    static var empty: String {
        L(
            "kiwivision.never_dimmed.empty",
            "No apps yet. An app you add here is never dimmed or "
                + "blurred, such as a status bar like SketchyBar."
        )
    }

    static var removeHelp: String {
        L("kiwivision.never_dimmed.remove", "Remove from this list")
    }

    static var help: String {
        L(
            "kiwivision.never_dimmed.help",
            "KiwiVision never dims or blurs the windows of these "
                + "apps, focused or not, in every profile. Only the "
                + "part you can see is clear: where "
                + "another window covers it, you see that window as "
                + "usual. Windows drawn beneath all others, like "
                + "SketchyBar's bar, show through the haze. The "
                + "switches above follow the focused window; this list "
                + "does not."
        )
    }
}

/// A Never dimmed row's app: its icon and name for a bundle id, or
/// the generic program icon and the raw name for a process without
/// one.
struct AppPickerRowLabel: View {
    let key: String

    var body: some View {
        HStack(spacing: 6) {
            Image(nsImage: AppIconCache.shared.icon(forBundleID: key))
                .resizable()
                .frame(width: AppIconCache.side, height: AppIconCache.side)
            Text(KeybindingCatalog.displayName(forBundleID: key))
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}
