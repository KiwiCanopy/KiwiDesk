import KiwiDeskCore
import SwiftUI

/// Reusable popover for naming and renaming operations
/// (#375, #843, code review 2026-08-12).
struct NameEditPopover: View {
    let seed: String
    /// Placeholder and accessibility label (#812).
    let placeholder: String
    let confirmLabel: (String) -> String
    let isValid: (String) -> Bool
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

/// Request state for presenting a `NameEditPopover` via `.popover(item:)`
/// (#843).
struct NameEditRequest: Identifiable, Equatable {
    let id: UUID
    let seed: String
    let subject: String?

    init(seed: String, subject: String? = nil) {
        self.id = UUID()
        self.seed = seed
        self.subject = subject
    }
}
