import Foundation

/// The text Copy Setup Prompt puts on the clipboard (#1685 ▸
/// Ruling 6a). English and never a catalog key: it is read by
/// the AI app's model, and its command path and JSON must reach
/// that model verbatim; the reply line asks it to answer the user
/// in their own language instead.
enum AISetupPrompt {
    /// The prompt for `executable`, the binary `kiwidesk mcp`
    /// runs from; `replyLanguage` is the English name of the
    /// Settings language, nil when that is English.
    static func text(
        executable: String,
        replyLanguage: String?
    ) -> String {
        var lines = [
            "Please connect KiwiDesk, my macOS window manager, to "
                + "this app as a local MCP server (stdio).",
            "",
            "Add this server to your MCP configuration, keeping any "
                + "servers already there:",
            "",
            MCPInvocation.serverEntry(executable: executable),
            "",
            "If your configuration uses another format, use the same "
                + "command and args. If you can edit your configuration "
                + "yourself, do it and tell me what you changed; "
                + "otherwise walk me through it step by step. The app "
                + "may need a restart to load the server, and KiwiDesk "
                + "must be running.",
        ]
        if let replyLanguage {
            lines += ["", "Reply in \(replyLanguage)."]
        }
        return lines.joined(separator: "\n")
    }

    /// English name of `locale`'s language, nil for English or an
    /// unknown code — the `Reply in …` line is owed only then.
    static func replyLanguage(for locale: String?) -> String? {
        guard let locale,
            Locale(identifier: locale).language.languageCode
                != .english
        else { return nil }
        return Locale(identifier: "en")
            .localizedString(forIdentifier: locale)
    }
}
