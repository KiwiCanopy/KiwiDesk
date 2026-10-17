import KiwiDeskCore
import SwiftUI

/// KiwiHub's field while Save as New Profile… names a profile
/// (#2359 ruling 3): its prompt and the one line beneath it.
extension JumpPanelView {
    var fieldName: String {
        model.isNaming ? ViewPickText.namingPrompt : model.scope.fieldName
    }

    /// The line under a naming field, also the field's VoiceOver
    /// hint: the name ↩ writes and that it then holds these
    /// screens, why the typing names no profile, or that the last
    /// save failed.
    var namingLine: String? {
        guard model.isNaming, let naming = model.naming else { return nil }
        if naming.failed { return ViewPickText.saveFailed }
        return naming.target.map(ViewPickText.savesAs)
            ?? ViewPickText.invalidName
    }

    @ViewBuilder var namingCaption: some View {
        if let line = namingLine {
            Text(line)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                // A long name gives up its middle, never the claim.
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(
                    .horizontal,
                    KeyPanelStyle.selectionInset + JumpRowView.padding
                )
                .padding(.bottom, 8)
                .accessibilityHidden(true)
        }
    }
}
