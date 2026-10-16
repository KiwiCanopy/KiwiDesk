# KiwiDesk for Claude Code

Set up and control [KiwiDesk](https://kiwidesk.kiwicanopy.com), the
tiling window manager for macOS, by asking Claude. The plugin connects
Claude Code to KiwiDesk's own MCP server (`kiwidesk mcp`) and adds a
skill that teaches Claude how to change layouts, Spaces, the bars,
looks and app rules live, and keep them only when you say so.

## Requirements

KiwiDesk 3.0 or later, installed in `/Applications` or
`~/Applications`, or with `kiwidesk` on your `PATH`. KiwiDesk has to
be running for most of its tools to answer.

## Install

```sh
/plugin marketplace add KiwiCanopy/kiwidesk-claude
/plugin install kiwidesk@kiwidesk
```

## Privacy Policy

The plugin and KiwiDesk's MCP server run entirely on your Mac and send
nothing anywhere. What Claude reads through the tools — your Spaces,
windows and their titles, your settings — is sent to the model by
Claude Code, under Anthropic's own terms.

## License

KiwiDesk is source-available under the Business Source License 1.1;
see [LICENSE](https://github.com/KiwiCanopy/KiwiDesk/blob/main/LICENSE).
