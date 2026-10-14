import KiwiDeskCore
import SwiftUI

/// The AI page (#1685 ▸ Ruling 6a): connect the user's own AI app
/// to `kiwidesk mcp`, what it can do, and ready-made prompts to
/// start from. Single column, no draft (`SettingsDetailPanelOffer`);
/// no status of any AI app, which KiwiDesk cannot read.
struct AISection: View {
    @EnvironmentObject private var localization: LocalizationManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                setup
                // Above the prompts, which grow with each tool: the
                // keep and privacy facts must stay in view (#1685).
                AICapabilitiesCard()
                prompts
            }
            .padding([.horizontal, .bottom], SettingsMetrics.paneInset)
        }
    }

    private var setup: some View {
        SettingsSection(SettingsCatalog.ai.setupCard) {
            VStack(alignment: .leading, spacing: 8) {
                Text(
                    L(
                        "ai.setup.intro",
                        "KiwiDesk has no AI of its own. Connect the AI "
                            + "app you already use, and set up and "
                            + "control KiwiDesk by asking it."
                    )
                )
                AISetupRow()
            }
        }
    }

    private var prompts: some View {
        SettingsSection(SettingsCatalog.ai.promptsCard) {
            ForEach(
                Array(AIRowOrder.readyMadePrompts.enumerated()),
                id: \.element.id
            ) { index, row in
                if index > 0 { Divider() }
                if case .ai(let key) = row,
                    let control = Self.control(for: key)
                {
                    AIPromptRow(key: key, control: control)
                }
            }
        }
    }

    /// The catalog declaration a census row anchors on, keyed on
    /// the row's label key (#1250).
    static func control(for key: AIKey) -> SettingsControl? {
        let catalog = SettingsCatalog.ai
        switch key {
        case .copySetupPrompt: return catalog.copySetupPrompt
        case .promptSpaces: return catalog.promptSpaces
        }
    }
}
