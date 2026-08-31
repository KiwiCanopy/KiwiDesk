import AppKit
import KiwiDeskCore
import SwiftUI

/// App rule row rendered as an editable natural-language sentence (turn 14a).
struct AppRuleRow: View {
    @ObservedObject var model: SettingsModel
    let app: String
    /// Base rules when editing stored profile (#109).
    let overrideBase: [String: SpaceID]?
    let overrideFloatBase: [String]?
    /// Whether row is a newly added session draft without saved rules.
    let isDraft: Bool
    let onDelete: () -> Void
    /// Target for restoring keyboard focus after deletion (#816).
    @FocusState.Binding var returningRow: String?
    /// Keeps titled editor visible while patterns are empty.
    @State private var editingTitles = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            sentence
            if floatFacet == .titled || editingTitles {
                AppRuleTitledEditor(
                    model: model,
                    app: app,
                    editingTitles: $editingTitles
                )
                .padding(.leading, 28)
                .opacity(floatInherited ? 0.55 : 1)
            }
        }
    }

    /// Sentence row driven by the localized `SentenceFrame`. The
    /// word order is the TRANSLATOR's, never this stack's — ja/ko
    /// are verb-final, so pieces stitched in Swift can never be
    /// grammatical. Spacing is 0: the frame's literals own it
    /// (`" opens in "`), and a stack gap would tear a ja/ko
    /// particle off the noun it hugs (`SentenceFrameTests` pins
    /// the literals arrive spaces-intact).
    private var sentence: some View {
        HStack(spacing: 0) {
            appIcon
                .padding(.trailing, 6)
            ForEach(frame.segments) { segment in
                switch segment.slot {
                case .text(let words):
                    Text(words).foregroundStyle(.secondary)
                case .argument(let position):
                    control(at: position)
                }
            }
            Spacer()
            deleteButton
        }
        .font(.callout)
    }

    /// Control mapped via `SentenceFrame.control(at:)`, so an
    /// unrecognized position draws NOTHING — never the last case a
    /// `default:` arm happens to name.
    @ViewBuilder
    private func control(at position: Int) -> some View {
        switch SentenceFrame.control(at: position) {
        case .appName:
            Text(KeybindingCatalog.displayName(forBundleID: app))
                .fontWeight(.medium)
        case .space:
            spaceMenu
                .opacity(spaceInherited ? 0.55 : 1)
                .focused($returningRow, equals: app)
        case .float:
            floatMenu.opacity(floatInherited ? 0.55 : 1)
        case nil:
            EmptyView()
        }
    }

    private var frame: SentenceFrame {
        SentenceFrame(
            L(
                "app_rules.sentence",
                "%1$@ opens in %2$@ and %3$@"
            )
        )
    }

    private var spaceInherited: Bool {
        guard let base = overrideBase, !isDraft else {
            return false
        }
        return model.config.appRules[app] == base[app]
    }

    private var floatInherited: Bool {
        guard let base = overrideFloatBase, !isDraft else {
            return false
        }
        return Set(FloatFacet.rules(base, app: app))
            == Set(
                FloatFacet.rules(
                    model.config.floatRules,
                    app: app
                )
            )
    }

    private var deleteButton: some View {
        Button {
            onDelete()
        } label: {
            Image(systemName: "trash")
        }
        .buttonStyle(.borderless)
        .iconButtonAffordance(removeHelp)
        .disabled(
            overrideBase != nil
                && model.config.appRules[app] == nil
                && floatFacet == .never
                && !isDraft
        )
    }

    private var removeHelp: String {
        overrideBase == nil
            ? L(
                "app_rules.remove_all.help",
                "Remove all rules for this app"
            )
            : L(
                "app_rules.remove_override.help",
                "Remove this profile's effective Space "
                    + "and float rules for this app"
            )
    }

    @ViewBuilder private var appIcon: some View {
        if let url = appURL {
            Image(
                nsImage: NSWorkspace.shared.icon(
                    forFile: url.path
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

    /// Application bundle URL resolved by bundle identifier.
    private var appURL: URL? {
        NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: app
        )
    }

    var floatFacet: FloatFacet {
        FloatFacet.current(
            model.config.floatRules,
            app: app
        )
    }

    var titlesEditing: Binding<Bool> { $editingTitles }
}
