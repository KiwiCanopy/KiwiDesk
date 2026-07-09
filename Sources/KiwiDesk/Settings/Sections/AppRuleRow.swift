import AppKit
import KiwiDeskCore
import SwiftUI

/// One app's rules (#68 §3.11): icon + name, then the Space
/// facet (Automatic or a pinned space) and the Float facet
/// (Never / All windows / Windows titled… with pattern chips).
struct AppRuleRow: View {
    @ObservedObject var model: SettingsModel
    let app: String
    let onDelete: () -> Void
    /// Keeps the titled editor visible while it has no
    /// patterns yet (an empty pattern set stores nothing).
    @State private var editingTitles = false
    @State private var customPattern = ""
    @State private var addingCustom = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            facetRows
            if floatFacet == .titled || editingTitles {
                titledEditor
                    .padding(.leading, 90)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            appIcon
            Text(app).fontWeight(.medium)
            Spacer()
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help(
                L(
                    "app_rules.remove_all.help",
                    "Remove all rules for this app"
                )
            )
        }
    }

    @ViewBuilder private var appIcon: some View {
        if let path = appPath {
            Image(
                nsImage: NSWorkspace.shared.icon(
                    forFile: path
                )
            )
            .resizable()
            .frame(width: 20, height: 20)
        } else {
            Image(systemName: "app.dashed")
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
        }
    }

    private var appPath: String? {
        [
            "/Applications/\(app).app",
            "/System/Applications/\(app).app",
        ].first {
            FileManager.default.fileExists(atPath: $0)
        }
    }

    // MARK: - Facets

    private var facetRows: some View {
        HStack(spacing: 24) {
            HStack(spacing: 6) {
                Text(L("app_rules.space", "Space"))
                    .foregroundStyle(.secondary)
                spaceMenu
            }
            HStack(spacing: 6) {
                Text(L("app_rules.float", "Float"))
                    .foregroundStyle(.secondary)
                floatPicker
            }
            Spacer()
        }
        .font(.callout)
        .padding(.leading, 28)
    }

    /// `app_rules[app]`; Automatic deletes the entry.
    private var spaceMenu: some View {
        let automatic = L("app_rules.automatic", "Automatic")
        return Menu {
            Button(automatic) {
                model.config.appRules[app] = nil
            }
            Divider()
            ForEach(model.config.spaces, id: \.raw) { space in
                Button(space.raw) {
                    model.config.appRules[app] = space
                }
            }
        } label: {
            Text(model.config.appRules[app]?.raw ?? automatic)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var floatFacet: FloatFacet {
        FloatFacet.current(
            model.config.floatRules,
            app: app
        )
    }

    private var floatPicker: some View {
        Menu {
            Button(L("app_rules.float.never", "Never")) {
                setNever()
            }
            Button(
                L("app_rules.float.all_windows", "All windows")
            ) { setAll() }
            Button(titledLabel) {
                // Re-selecting the active choice must not
                // wipe the pattern list (#68 review m3).
                if floatFacet != .titled {
                    setNever()
                }
                editingTitles = true
            }
        } label: {
            Text(floatLabel)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var titledLabel: String {
        L("app_rules.float.titled", "Windows titled…")
    }

    private var floatLabel: String {
        switch floatFacet {
        case .never:
            return editingTitles
                ? titledLabel
                : L("app_rules.float.never", "Never")
        case .all:
            return L("app_rules.float.all_windows", "All windows")
        case .titled: return titledLabel
        }
    }

    // MARK: - Titled patterns

    private var patterns: [String] {
        FloatFacet.patterns(
            model.config.floatRules,
            app: app
        )
    }

    private var titledEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !patterns.isEmpty {
                WrapChips(patterns) { pattern in
                    patternChip(pattern)
                }
            }
            HStack(spacing: 8) {
                addWindowMenu
                if addingCustom {
                    TextField(
                        L(
                            "app_rules.title_contains",
                            "Title contains…"
                        ),
                        text: $customPattern
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                    .onSubmit { commitCustom() }
                    Button(L("app_rules.add", "Add")) {
                        commitCustom()
                    }
                    .disabled(customPattern.trimmed.isEmpty)
                }
            }
            Text(titledPatternCaption)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var titledPatternCaption: String {
        L(
            "app_rules.titled.caption",
            "Windows whose title contains a pattern "
                + "stay floating."
        )
    }

    private func patternChip(_ pattern: String) -> some View {
        HStack(spacing: 4) {
            Text(pattern)
                .font(.caption)
            Button {
                removePattern(pattern)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 9))
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(.tint.opacity(0.15)))
        .overlay(
            Capsule().strokeBorder(.tint.opacity(0.4))
        )
    }

    /// Lists the app's currently open, not-yet-covered window
    /// titles, plus the free-text escape for windows that
    /// aren't open right now.
    private var addWindowMenu: some View {
        Menu {
            ForEach(openTitles, id: \.self) { title in
                Button(title) { addPattern(title) }
            }
            if !openTitles.isEmpty { Divider() }
            Button(
                L("app_rules.other_specify", "Other (Specify)…")
            ) {
                addingCustom = true
            }
        } label: {
            Label(
                L("app_rules.add_window", "Add Window"),
                systemImage: "plus"
            )
            .font(.caption)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var openTitles: [String] {
        let covered = patterns
        return Set(
            model.core.state.windows.all
                .filter { $0.appName == app }
                .map(\.title)
        )
        .subtracting(covered)
        .filter { !$0.isEmpty }
        .sorted()
    }

    // MARK: - Mutations (GUI assembles the colon syntax)

    private func setNever() {
        editingTitles = false
        model.config.floatRules.removeAll {
            FloatFacet.appSegment(of: $0) == app
        }
    }

    private func setAll() {
        setNever()
        model.config.floatRules.append(app)
    }

    private func addPattern(_ pattern: String) {
        let rule = "\(app):\(pattern)"
        model.config.floatRules.removeAll { $0 == app }
        guard !model.config.floatRules.contains(rule) else {
            return
        }
        model.config.floatRules.append(rule)
        editingTitles = true
    }

    private func removePattern(_ pattern: String) {
        model.config.floatRules.removeAll {
            $0 == "\(app):\(pattern)"
        }
        if patterns.isEmpty { editingTitles = true }
    }

    private func commitCustom() {
        let pattern = customPattern.trimmed
        guard !pattern.isEmpty else { return }
        addPattern(pattern)
        customPattern = ""
        addingCustom = false
    }
}
