import KiwiDeskCore
import SwiftUI

/// Naming a palette — the one popover behind both Save and
/// Rename (#375, #843).
///
/// **It owns the name it edits.** Both call sites used to seed a
/// `@State` on the shelf in the same tick that presented the
/// popover, and that is the bug #843 reports: the field renders
/// through a `Binding` so it showed the seeded name, while the
/// confirm button's `.disabled(…)` was evaluated against the view
/// value SwiftUI captured at presentation — the empty one. Save
/// was therefore dead on the first open of every visit, live on
/// the second, and dead again after a remount, with a perfectly
/// valid name in the field the whole time.
///
/// Seeding here removes the ordering rather than sequencing it:
/// `seed` is a plain parameter, read from a value the caller
/// already holds (the palette's own name, or a freshly computed
/// unique one), so there is no shelf state for a snapshot to be
/// stale about. A re-seed inside `onAppear` would have fixed the
/// symptom and kept the dependency alive in a second place.
///
/// The validity rule stays the CALLER's — `canSave` and
/// `canRename` differ (a rename may keep its own name; a save may
/// not take an existing one silently) — so this view takes it as
/// a function of the typed name and never re-derives it.
struct PaletteNamePopover: View {
    let seed: String
    let confirmLabel: (String) -> String
    let isValid: (String) -> Bool
    /// The caption under the field — a reserved name, a duplicate
    /// warning — or nil while there is nothing to say.
    let notice: (String) -> String?
    let onConfirm: (String) -> Void
    let width: CGFloat
    @State private var name: String

    init(
        seed: String,
        width: CGFloat = 220,
        confirmLabel: @escaping (String) -> String,
        isValid: @escaping (String) -> Bool,
        notice: @escaping (String) -> String? = { _ in nil },
        onConfirm: @escaping (String) -> Void
    ) {
        self.seed = seed
        self.width = width
        self.confirmLabel = confirmLabel
        self.isValid = isValid
        self.notice = notice
        self.onConfirm = onConfirm
        _name = State(initialValue: seed)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(
                L("palettes.name_placeholder", "Palette name"),
                text: $name
            )
            .textFieldStyle(.roundedBorder)
            .frame(width: width)
            .onSubmit(confirm)
            if let notice = notice(name) {
                Text(notice)
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.ink3)
                    .frame(width: width, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Button(confirmLabel(name), action: confirm)
                    .kiwiProminentButton()
                    .disabled(!isValid(name))
            }
        }
        .padding(12)
    }

    private func confirm() {
        guard isValid(name) else { return }
        onConfirm(name)
    }
}
