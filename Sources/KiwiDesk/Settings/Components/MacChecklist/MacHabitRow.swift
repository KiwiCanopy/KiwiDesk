import KiwiDeskCore
import SwiftUI

/// One habit on the checklist (#1365): a bold lead phrase and
/// one sentence, read-only — a habit is kept, never found done,
/// so it carries no tick and joins no count. Where the sentence
/// names a KiwiDesk surface it is a `CrossReferenceRow`, headed
/// by that destination's own title.
struct MacHabitRow: View {
    let key: MacChecklistKey
    let control: SettingsControl

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(control.text)
                .font(.body.weight(.semibold))
                .foregroundStyle(SettingsTheme.ink)
            sentence
        }
        .searchAnchored(control)
    }

    @ViewBuilder private var sentence: some View {
        let prose = MacChecklistText.habit(for: key)
        if let destination = key.destination {
            CrossReferenceRow(
                prose: prose,
                linkTitle: destination.title,
                destination: destination
            )
        } else {
            Text(prose)
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
