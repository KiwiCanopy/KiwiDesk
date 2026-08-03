import AppKit
import KiwiDeskCore
import SwiftUI

/// One app's rules as a **sentence** (turn 14a): "Spotify opens
/// in media ▾ and floats ▾", with the title patterns as chips
/// underneath when the float facet asks for them.
///
/// The sentence IS the control. The row used to be an app
/// header over two labelled facet columns — "Space [ media ▾ ]
/// Float [ Windows titled… ▾ ]" — which reads as a form about
/// an app rather than as the rule itself, and made the user
/// assemble the meaning from three fragments. A rule is a
/// statement about what an app does, so the row states it and
/// the two menus sit inside the statement where their values
/// complete it.
///
/// The facet values became verb phrases with that move
/// ("floats", "tiles normally") because a menu inside a
/// sentence has to read as part of it; "Never" completed
/// nothing. The labels the values replaced are not lost —
/// they are the menus' accessibility labels, which is also
/// what keeps them findable in search, since a sentence has no
/// visible label for a screen reader or a search index to name
/// the facet by.
struct AppRuleRow: View {
    @ObservedObject var model: SettingsModel
    let app: String
    /// The base rules while editing a stored profile (#109):
    /// non-nil switches the row into override mode. Each facet
    /// independently dims while it still matches its base.
    let overrideBase: [String: SpaceID]?
    let overrideFloatBase: [String]?
    /// Whether the row is a session draft (added this session,
    /// no stored facet yet) — deleting one always works, it
    /// removes the draft itself.
    let isDraft: Bool
    let onDelete: () -> Void
    /// Keeps the titled editor visible while it has no
    /// patterns yet (an empty pattern set stores nothing).
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

    /// The sentence, in one row: icon, then the frame with the
    /// app name and the two facet menus dropped into it.
    ///
    /// **The word order is the translator's, not this stack's.**
    /// An earlier cut emitted "opens in" and "and" as separate
    /// keys between fixed `HStack` positions, which is the harm
    /// localization.md names — a translation cannot reorder
    /// pieces stitched together in Swift, and ja/ko are
    /// verb-final, so no catalog edit could have produced a
    /// grammatical row. The frame is one key with positional
    /// specifiers; `SentenceFrame` splits it on those and this
    /// emits the pieces in whatever order the translation put
    /// them.
    private var sentence: some View {
        HStack(spacing: 6) {
            appIcon
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

    /// The control a slot draws, mapped through
    /// `SentenceFrame.control(at:)` so the mapping is assertable
    /// and an unrecognized position draws NOTHING — never the
    /// last case a `default:` arm happens to name.
    @ViewBuilder
    private func control(at position: Int) -> some View {
        switch SentenceFrame.control(at: position) {
        case .appName:
            Text(KeybindingCatalog.displayName(forBundleID: app))
                .fontWeight(.medium)
        case .space:
            spaceMenu.opacity(spaceInherited ? 0.55 : 1)
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

    // MARK: - Inheritance (override mode)

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

    // MARK: - Chrome

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
                "Remove this profile's effective space "
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

    /// The installed bundle for this rule's app, resolved from
    /// its bundle id — nil (dashed placeholder) when the app
    /// isn't installed on this machine.
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
