import KiwiDeskCore
import SwiftUI

/// A lens's Apps card (#2103 rulings 29, 31, 32, 51): the member
/// apps, each "All windows" or "Windows titled…" through the shared
/// title editor, and "Add an app…" through the one app picker.
struct KiwiVisionLensAppsCard: View {
    @ObservedObject var model: SettingsModel
    let lens: VisionLens

    var body: some View {
        SettingsSection(
            KiwiVisionLensWords.appsTitle,
            caption: KiwiVisionLensWords.appsCaption(lens.name),
            help: KiwiVisionLensWords.appsHelp
        ) {
            VStack(alignment: .leading, spacing: 6) {
                if lens.apps.isEmpty {
                    Text(KiwiVisionLensWords.appsEmpty(lens.name))
                        .font(.caption)
                        .foregroundStyle(SettingsTheme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(lens.apps, id: \.self) { app in
                    row(app)
                    Divider()
                }
                addButton
            }
        }
    }

    @ViewBuilder private func row(_ app: String) -> some View {
        let titled = lens.titles[app] != nil
        HStack(spacing: 6) {
            AppPickerRowLabel(key: app)
            Spacer(minLength: 0)
            scopeMenu(app, titled: titled)
            AppRuleDeleteButton(help: KiwiVisionLensWords.removeApp) { _ in
                update {
                    $0.apps.removeAll { $0 == app }
                    $0.titles[app] = nil
                }
            }
        }
        if titled {
            WindowTitleEditor(
                model: model,
                patterns: titles(of: app),
                app: app,
                caption: (lens.titles[app] ?? []).isEmpty
                    ? KiwiVisionLensWords.titledEmptyCaption
                    : KiwiVisionLensWords.titledCaption
            ) { _ in EmptyView() }
            .padding(.leading, AppIconCache.side + 6)
        }
    }

    private func scopeMenu(_ app: String, titled: Bool) -> some View {
        let value =
            titled
            ? KiwiVisionLensWords.titledWindows
            : KiwiVisionLensWords.allWindows
        return Picker(
            KiwiVisionLensWords.windowsLabel,
            selection: Binding(
                get: { titled },
                set: { on in update { $0.titles[app] = on ? [] : nil } }
            )
        ) {
            Text(KiwiVisionLensWords.allWindows).tag(false)
            Text(KiwiVisionLensWords.titledWindows).tag(true)
        }
        .pickerStyle(.menu)
        .neutralMenuLabel()
        .labelsHidden()
        .fixedSize()
        .accessibilityLabel(KiwiVisionLensWords.windowsLabel)
        .accessibilityValue(value)
    }

    private func titles(of app: String) -> Binding<[String]> {
        Binding(
            get: { lens.titles[app] ?? [] },
            set: { patterns in update { $0.titles[app] = patterns } }
        )
    }

    private var addButton: some View {
        AppPickerButton(
            placeholder: KiwiVisionLensWords.addApp,
            selection: nil,
            onPick: { add($0.bundleID) },
            escapeLabel: L("shortcuts.other_ellipsis", "Other…"),
            onEscape: {
                if let app = AppBundlePanel.pick() { add(app.bundleID) }
            },
            exclude: Set(lens.apps),
            onScreen: { model.core.appsOnScreen(beneathNormal: false) }
        )
        .fixedSize()
        .accessibilityLabel(KiwiVisionLensWords.appsTitle)
        .accessibilityValue(KiwiVisionLensWords.addApp)
    }

    private func add(_ key: String) {
        update {
            $0.apps = AppWideSettings.neverDimmedEntries($0.apps + [key])
        }
    }

    private func update(_ change: (inout VisionLens) -> Void) {
        model.updateLens(lens.name, change)
    }
}
