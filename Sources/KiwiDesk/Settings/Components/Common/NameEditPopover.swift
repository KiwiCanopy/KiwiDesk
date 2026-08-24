import KiwiDeskCore
import SwiftUI

/// Naming a thing — the one popover behind every "type a name
/// and confirm" in Settings (#375, #843): saving a palette,
/// renaming a palette, a profile or a layer.
///
/// In `Common/` because it is shared across component areas
/// (Colours, Profiles, Shortcuts), which is what that directory
/// admits.
///
/// **It owns the name it edits.** All four call sites used to
/// seed a `@State` on the parent in the same tick that presented
/// the popover, and that is the bug #843 reports: the field renders
/// through a `Binding` so it showed the seeded name, while the
/// confirm button's `.disabled(…)` was evaluated against the view
/// value SwiftUI captured at presentation — the empty one. Save
/// was therefore dead on the first open of every visit, live on
/// the second, and dead again after a remount, with a perfectly
/// valid name in the field the whole time.
///
/// Seeding here removes the ordering rather than sequencing it:
/// `seed` arrives as part of the presented ITEM, so the content
/// is built from a value handed to the builder rather than read
/// back out of parent state. A re-seed inside `onAppear` would
/// have fixed the symptom and kept the dependency alive in a
/// second place.
///
/// The item also carries a fresh id per presentation, which is
/// what makes the `@State` below fresh: seeded in `init`, it
/// would otherwise persist if SwiftUI reused the content view
/// between presentations — and a reused name turns the save's
/// confirm into "Overwrite" over a palette the user already
/// saved, a silent clobber the write-then-present code could not
/// produce (code review, 2026-08-12).
///
/// The validity rule stays the CALLER's — `canSave` and
/// `canRename` differ (a rename may keep its own name; a save may
/// not take an existing one silently) — so this view takes it as
/// a function of the typed name and never re-derives it.
struct NameEditPopover: View {
    let seed: String
    /// The field's title — what VoiceOver calls it and what an
    /// empty field shows. The caller's, because the popover is
    /// shared: seeded with the palette key it announced
    /// "Palette name" over a profile rename (#812).
    let placeholder: String
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
        placeholder: String,
        width: CGFloat = 220,
        confirmLabel: @escaping (String) -> String,
        isValid: @escaping (String) -> Bool,
        notice: @escaping (String) -> String? = { _ in nil },
        onConfirm: @escaping (String) -> Void
    ) {
        self.seed = seed
        self.placeholder = placeholder
        self.width = width
        self.confirmLabel = confirmLabel
        self.isValid = isValid
        self.notice = notice
        self.onConfirm = onConfirm
        _name = State(initialValue: seed)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(placeholder, text: $name)
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
                // The SYSTEM prominent style, deliberately: its
                // disabled state is flat grey, and this button's
                // disabled state is the thing #843 was about —
                // `kiwiProminentButton()` draws disabled and
                // pressed alike (a dimmed accent fill), which
                // reads as live. Adopting that seal here is its
                // own change and its own eye-confirm (gui.md ▸
                // Colour).
                Button(confirmLabel(name), action: confirm)
                    .buttonStyle(.borderedProminent)
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

/// One presentation of `NameEditPopover`, carrying its seed.
///
/// Presented through `.popover(item:)` rather than
/// `isPresented:` — the builder is handed this value, so the
/// content can never be built from parent state written in the
/// same tick (#843), and the fresh `id` gives each presentation
/// its own `@State`.
struct NameEditRequest: Identifiable, Equatable {
    let id: UUID
    let seed: String
    /// The name being replaced, for a rename — nil when the
    /// popover is naming something new.
    let subject: String?

    init(seed: String, subject: String? = nil) {
        self.id = UUID()
        self.seed = seed
        self.subject = subject
    }
}
