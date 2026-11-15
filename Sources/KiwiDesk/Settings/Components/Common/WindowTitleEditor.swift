import KiwiDeskCore
import SwiftUI

/// Editor for the title patterns that pick some of an app's
/// windows (#68 §3.11, #2103 ruling 43): a chip per pattern, the
/// one `TitlePatternComposer`, the caller's preview of what the
/// patterns match and its caption. A pattern
/// matches as `WindowTitleMatch` reads it; where the patterns are
/// stored is the caller's.
struct WindowTitleEditor<Preview: View>: View {
    @ObservedObject var model: SettingsModel
    @Binding var patterns: [String]
    /// The app's bundle id, whose open windows the menu offers.
    let app: String
    let caption: String
    /// What the patterns match, handed the pattern being typed.
    @ViewBuilder let preview: (String) -> Preview
    /// The pending pattern; internal so a test can mount it open.
    @State var draft = TitlePatternDraft()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !shown.isEmpty {
                WrapChips(shown) { pattern in
                    patternChip(pattern)
                }
            }
            TitlePatternComposer(
                model: model,
                draft: $draft,
                app: app,
                covered: shown,
                onCommit: addPattern
            )
            preview(draft.isOpen ? draft.text : "")
            Text(caption)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    /// Deduplicated, because the chips are identified by VALUE.
    /// `addPattern` refuses a duplicate, but a store decoded
    /// straight from JSON can repeat one — which under value
    /// identity is two `ForEach` children claiming one id (code
    /// review, 2026-08-04). Order is the store's; only the repeat
    /// is dropped.
    private var shown: [String] {
        var seen: Set<String> = []
        return patterns.filter { seen.insert($0).inserted }
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
            .iconButtonAffordance(
                L(
                    "app_rules.remove_pattern",
                    "Remove title pattern"
                )
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(.tint.opacity(0.15)))
        .overlay(
            Capsule().strokeBorder(.tint.opacity(0.4))
        )
    }

    // MARK: - Mutations

    private func addPattern(_ pattern: String) {
        guard !patterns.contains(pattern) else { return }
        patterns.append(pattern)
    }

    private func removePattern(_ pattern: String) {
        patterns.removeAll { $0 == pattern }
    }
}
