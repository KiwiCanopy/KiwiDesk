import KiwiDeskCore
import SwiftUI

/// The section's one open title popover (#3373): the row it hangs
/// off, and whether it changes that row's title or adds a rule.
struct SpaceComposer: Identifiable, Equatable {
    let request: TitlePatternRequest
    /// The row whose scope cell the popover hangs off.
    let row: SpaceRuleRow
    /// Change Title…: the popover rewrites `row`'s fragment. Add
    /// Rule…: it adds a titled rule in `row`'s Space.
    let changes: Bool

    var id: UUID { request.id }

    init(row: SpaceRuleRow, changes: Bool) {
        self.row = row
        self.changes = changes
        request = TitlePatternRequest(
            seed: changes ? row.fragment ?? "" : ""
        )
    }
}

/// A Space row's scope cell (#3341, #3373): which of the app's
/// windows the row takes, as a menu, with the title popover hung
/// off it. A pattern scopes exactly this row, beside its own Space
/// menu, and no chip editor hangs under it (#1608 ▸ amended).
extension AppRuleSpaceRow {
    var scopeCell: some View {
        scopeMenu
            .popover(item: composerBinding, arrowEdge: .bottom) {
                composer in
                TitlePatternPopover(
                    model: model,
                    app: row.app,
                    covered: siblings,
                    seed: composer.request.seed,
                    refusal: { refusal($0, changing: composer) },
                    preview: { pending in
                        SpaceRuleMatchPreview(
                            model: model,
                            row: composer.changes
                                ? row
                                : SpaceRuleRow(app: row.app, fragment: ""),
                            space: SpaceRuleRows.space(
                                of: row,
                                in: model.config
                            ),
                            pending: pending
                        )
                    },
                    onCommit: { commit($0, from: composer) },
                    onCancel: { composing = nil }
                )
                .settingsPopoverChrome()
            }
            // One width for every row, so the Space and "Applies to"
            // columns line up across an app's rows (#3415); outside
            // the popover, whose arrow stays on the menu.
            .frame(
                width: SettingsMetrics.appRuleScopeColumn,
                alignment: .leading
            )
    }

    /// The section's composer, shown only off the row it names.
    private var composerBinding: Binding<SpaceComposer?> {
        Binding(
            get: { composing?.row == row ? composing : nil },
            // A late dismiss of this row's popover never closes
            // another row's.
            set: { if $0 == nil, composing?.row == row { composing = nil } }
        )
    }

    /// The bare row: its one scope, checked, and the door to a
    /// titled rule. A titled row: the bare row it would become
    /// (greyed while the app has one), its own title, and another
    /// rule (#3373, #3415).
    private var scopeMenu: some View {
        AppRuleScopeFit.menu(scopeLabel) {
            if row.fragment == nil {
                // Checked under the cell's own words: "All other
                // windows" beside titled rows.
                Toggle(scopeLabel, isOn: .constant(true))
            } else {
                Button(becomesLabel) {
                    let bare = SpaceRuleRow(app: row.app, fragment: nil)
                    model.moveSpaceRule(from: row, to: bare) {
                        SpaceRuleEdit.makeBare(row, in: &$0)
                    }
                }
                .disabled(hasBare)
                if hasBare {
                    Button(AppRuleScopeWords.allTaken) {}.disabled(true)
                }
                Button(AppRuleScopeWords.changeTitle) { open(true) }
            }
            Button(AppRuleScopeWords.addTitled) { open(false) }
        }
        .help(row.fragment ?? "")
        .accessibilityLabel(AppRuleScopeWords.menuName)
        .accessibilityValue(scopeLabel)
    }

    /// The drawn and spoken scope, one expression.
    var scopeLabel: String {
        guard let fragment = row.fragment else {
            return AppRuleScopeWords.bare(besideOthers: othersBeside)
        }
        return AppRuleScopeWords.titled(fragment)
    }

    /// The bare row a titled row's scope item would make: "All
    /// other windows" while the app keeps other rows (#3415).
    var becomesLabel: String {
        AppRuleScopeWords.bare(besideOthers: othersBeside)
    }

    private var othersBeside: Bool {
        SpaceRuleRows.othersBeside(row, in: model.config)
    }

    private var hasBare: Bool { model.config.appRules[row.app] != nil }

    private func open(_ changes: Bool) {
        composing = SpaceComposer(row: row, changes: changes)
    }

    /// A fragment the app's titled rows hold already; Change Title…
    /// may keep its own.
    private func refusal(
        _ typed: String,
        changing composer: SpaceComposer
    ) -> String? {
        let current = composer.changes ? row.fragment : nil
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

    /// Change Title… rewrites the row; Add Rule… adds a titled rule
    /// in the row's Space, whose own menu then moves it.
    private func commit(_ fragment: String, from composer: SpaceComposer) {
        composing = nil
        if composer.changes {
            let moved = SpaceRuleRow(app: row.app, fragment: fragment)
            model.moveSpaceRule(from: row, to: moved) {
                SpaceRuleEdit.setFragment(fragment, of: row, in: &$0)
            }
        } else {
            guard
                SpaceRuleEdit.addTitled(
                    fragment,
                    beside: row,
                    config: &model.config
                )
            else { return }
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
