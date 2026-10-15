import Foundation
import Testing

/// `.github/workflows/claude-plugin.yml` (#2258 ▸ Ruling 3): on a
/// published release it copies the RELEASED tag's `plugins/` to
/// KiwiCanopy/kiwidesk-claude with the release's version, through
/// that repository's own deploy key.
@Suite("Claude plugin sync workflow")
struct ClaudePluginSyncWorkflowTests {
    static let file = "claude-plugin.yml"

    @Test("it runs on publication, never on a draft or a tag push")
    func trigger() throws {
        let yaml = try workflowSource(Self.file)
        #expect(yaml.contains("release:\n    types: [published]"))
        #expect(!yaml.contains("push:"))
    }

    @Test("it copies the released source, not main")
    func releasedSource() throws {
        let yaml = try workflowSource(Self.file)
        #expect(yaml.contains("ref: ${{ env.TAG }}"))
        let copy = try workflowStep(
            "Copy the plugin and stamp its version",
            in: yaml
        )
        #expect(
            copy.contains(
                "rsync -a --delete --exclude .git kiwidesk/plugins/ "
                    + "marketplace/"
            )
        )
        #expect(copy.contains("jq --arg v \"$VERSION\" '.version = $v'"))
        #expect(copy.contains("kiwidesk/.claude-plugin/plugin.json"))
    }

    @Test("it writes through the marketplace's deploy key")
    func deployKey() throws {
        let yaml = try workflowSource(Self.file)
        #expect(yaml.contains("repository: KiwiCanopy/kiwidesk-claude"))
        let uses =
            yaml.components(
                separatedBy: "secrets.CLAUDE_PLUGIN_DEPLOY_KEY"
            ).count - 1
        #expect(uses == 2)
        let push = try workflowStep("Commit and push", in: yaml)
        #expect(push.contains("git -C marketplace push origin HEAD:main"))
    }
}
