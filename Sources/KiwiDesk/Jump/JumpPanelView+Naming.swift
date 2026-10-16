import KiwiDeskCore
import SwiftUI

/// KiwiHub's field while Save as New Profile… names a profile
/// (#2359 ruling 3): its prompt and the one line beneath it.
extension JumpPanelView {
    /// Whether the field names a profile (#2359 ruling 3).
    var naming: Bool { model.profileNaming != nil }

    var fieldName: String {
        naming ? ViewPickText.namingPrompt : model.scope.fieldName
    }

    /// The one line under a naming field: the name ↩ writes and
    /// that it becomes these screens' default, or why the typing
    /// names no profile (#2359 ruling 3).
    @ViewBuilder var namingCaption: some View {
        if naming {
            Text(
                model.namingFailed
                    ? ViewPickText.saveFailed
                    : model.namingTarget.map(ViewPickText.savesAs)
                        ?? ViewPickText.invalidName
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(
                .horizontal,
                KeyPanelStyle.selectionInset + JumpRowView.padding
            )
            .padding(.bottom, 8)
        }
    }
}
