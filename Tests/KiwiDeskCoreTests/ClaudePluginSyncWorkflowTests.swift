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
        // Each ref read beside its own checkout's path, since
        // a file-wide needle passed with the two refs swapped.
        #expect(
            yaml.contains("ref: ${{ env.TAG }}\n          path: kiwidesk")
        )
        #expect(yaml.contains("ref: main\n          path: marketplace"))
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
        #expect(
            copy.contains(
                "MANIFEST=\"marketplace/$FOLDER/.claude-plugin/plugin.json\""
            )
        )
        #expect(copy.contains("cp kiwidesk/LICENSE marketplace/LICENSE"))
    }

    /// The folder comes from the marketplace file, so a renamed
    /// plugin cannot skip the sync silently.
    @Test("it finds the plugin through the marketplace file")
    func folderFromMarketplace() throws {
        let yaml = try workflowSource(Self.file)
        let skip = try workflowStep(
            "Skip a release without the plugin",
            in: yaml
        )
        #expect(skip.contains("plugins/.claude-plugin/marketplace.json"))
        #expect(skip.contains("jq -r '.plugins[0].source' \"$MARKET\""))
    }

    /// A manual retry is a retry of a PUBLISHED release, as the
    /// Homebrew cask's is.
    @Test("a manual run refuses a draft's tag")
    func refusesDrafts() throws {
        let yaml = try workflowSource(Self.file)
        let check = try workflowStep("Check the tag", in: yaml)
        #expect(check.contains("releases/tags/$TAG"))
        #expect(check.contains("if [ \"$DRAFT\" != false ]; then"))
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
