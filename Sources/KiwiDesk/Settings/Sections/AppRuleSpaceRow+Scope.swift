import KiwiDeskCore
import SwiftUI

/// The section's one open Space composer (#3341): the row whose
/// fragment is being written, or a new titled row for `app`.
struct SpaceComposer: Equatable {
    let app: String
    /// The row composing; nil for a new titled row.
    let row: SpaceRuleRow?
}

/// A Space row's scope cell (#3341): which of the app's windows the
/// row takes, as a menu, or the composer in its place while one of
/// its fragments is written. A pattern scopes exactly this row,
/// beside its own Space menu, and no chip editor hangs under it
/// (#1608 ▸ amended).
extension AppRuleSpaceRow {
    /// A new titled row, drawn with its composer and no Space yet.
    var isDraft: Bool { row.fragment == "" }

    var composingHere: Bool {
        guard let composing, composing.app == row.app else { return false }
        return isDraft ? composing.row == nil : composing.row == row
    }

    /// The Space the composed rule opens windows in: the row's own,
    /// or for a new row the one a picker pick takes.
    var composedSpace: SpaceID? {
        isDraft
            ? AppRulePin.engagedSpace(model.config)
            : SpaceRuleRows.space(of: row, in: model.config)
    }

    @ViewBuilder var scopeCell: some View {
        if composingHere {
            TitlePatternComposer(
                model: model,
                draft: $draft,
                app: row.app,
                covered: siblings,
                refusal: refusal,
                onCommit: commit,
                onCancel: { composing = nil }
            )
            .onAppear { draft.start(with: row.fragment ?? "") }
        } else {
            scopeMenu
        }
    }

    /// "All windows" and "Windows titled…", as on a Float row, and
    /// the door to another titled row of the app.
    private var scopeMenu: some View {
        Menu {
            Button(AppRuleScopeWords.all) {
                let bare = SpaceRuleRow(app: row.app, fragment: nil)
                model.moveSpaceRule(from: row, to: bare) {
                    SpaceRuleEdit.makeBare(row, in: &$0)
                }
            }
            .disabled(row.fragment != nil && hasBare)
            if row.fragment != nil, hasBare {
                Button(AppRuleScopeWords.allTaken) {}.disabled(true)
            }
            Button(AppRuleScopeWords.titledItem) { open(row) }
            Divider()
            Button(AppRuleScopeWords.addTitled) { open(nil) }
        } label: {
            AppRuleMenuLabel(text: scopeLabel, chevron: false)
                .truncationMode(.middle)
        }
        .menuStyle(.borderlessButton)
        .neutralMenuLabel()
        .fixedSize()
        .menuTriggerHover()
        .help(row.fragment ?? "")
        .accessibilityLabel(AppRuleScopeWords.menuName)
        .accessibilityValue(scopeLabel)
    }

    /// The drawn and spoken scope, one expression.
    var scopeLabel: String {
        guard let fragment = row.fragment else {
            return siblings.isEmpty
                ? AppRuleScopeWords.all : AppRuleScopeWords.allOther
        }
        return AppRuleScopeWords.titled(fragment)
    }

    private var hasBare: Bool { model.config.appRules[row.app] != nil }

    private func open(_ target: SpaceRuleRow?) {
        composing = SpaceComposer(app: row.app, row: target)
    }

    /// A fragment the app's other titled rows hold already.
    private func refusal(_ typed: String) -> String? {
        let current = isDraft ? nil : row.fragment
        guard
            SpaceRuleEdit.repeats(
                typed,
                app: row.app,
                except: current,
                in: model.config
            )
        else { return nil }
        return AppRuleScopeWords.duplicate(app: appName, typed)
    }

    private func commit(_ fragment: String) {
        composing = nil
        if isDraft {
            guard let space = composedSpace else { return }
            SpaceRuleEdit.addTitled(
                fragment,
                for: row.app,
                in: space,
                config: &model.config
            )
        } else {
            let moved = SpaceRuleRow(app: row.app, fragment: fragment)
            model.moveSpaceRule(from: row, to: moved) {
                SpaceRuleEdit.setFragment(fragment, of: row, in: &$0)
            }
        }
        returningRow = SpaceRuleRow(app: row.app, fragment: fragment).key
    }
}

/// Names a group's later rows for VoiceOver, whose app the first row
/// alone draws (#3341).
struct SpaceRowGroupName: ViewModifier {
    let name: String?

    func body(content: Content) -> some View {
        if let name {
            content
                .accessibilityElement(children: .contain)
                .accessibilityLabel(name)
        } else {
            content
        }
    }
}
