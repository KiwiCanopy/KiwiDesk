import KiwiDeskCore
import SwiftUI

/// What a Space name field's draft earns while focused (#1623): a
/// refusal for a name another Space holds, a hint for an empty
/// one. Derived from the draft, never stored by the field.
enum SpaceNameNotice: Equatable {
    case taken(String)
    case empty(keeping: String)

    static func of(
        draft: String,
        space: SpaceID,
        isAvailable: (SpaceID) -> Bool
    ) -> SpaceNameNotice? {
        let target = SpaceID(draft.trimmed)
        if target.raw.isEmpty { return .empty(keeping: space.raw) }
        guard target != space, !isAvailable(target) else {
            return nil
        }
        return .taken(target.raw)
    }

    @MainActor var sentence: String {
        switch self {
        case .taken(let name):
            L(
                "spaces.rename.taken",
                "A Space named “%1$@” already exists.",
                name
            )
        case .empty(let name):
            L(
                "spaces.rename.empty",
                "Type a name, or it goes back to “%1$@”.",
                name
            )
        }
    }

    /// A refusal is drawn in `danger` with a shape cue beside the
    /// text (WCAG 1.4.1); a hint stays secondary.
    var isRefusal: Bool {
        if case .taken = self { return true }
        return false
    }
}

/// The caption a row draws under itself for its field's notice.
struct SpaceNameNoticeCaption: View {
    let notice: SpaceNameNotice

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if notice.isRefusal {
                Image(systemName: "exclamationmark.triangle.fill")
                    .accessibilityHidden(true)
            }
            Text(notice.sentence)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption)
        .foregroundStyle(
            notice.isRefusal
                ? AnyShapeStyle(SettingsTheme.danger)
                : AnyShapeStyle(.secondary)
        )
    }
}
