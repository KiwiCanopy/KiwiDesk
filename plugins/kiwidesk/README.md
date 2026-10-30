# KiwiDesk for Claude Code

Set up and control [KiwiDesk](https://kiwidesk.kiwicanopy.com), the
tiling window manager for macOS, by asking Claude. The plugin connects
Claude Code to KiwiDesk's own MCP server (`kiwidesk mcp`) and adds a
skill that teaches Claude how to change layouts, Spaces, the bars,
looks and app rules live, and keep them only when you say so.

## Requirements

macOS only. KiwiDesk 3.0 or later, installed in `/Applications` or
`~/Applications`, or with `kiwidesk` on your `PATH`. KiwiDesk has to
be running for most of its tools to answer.

## What it runs

The plugin bundles no server of its own. Its launcher,
`scripts/kiwidesk-mcp`, looks for the installed KiwiDesk app in
`/Applications`, then `~/Applications`, then `kiwidesk` on your
`PATH`, and starts that binary as `KiwiDesk mcp`, a local MCP server
that talks to Claude Code over standard input and output. If KiwiDesk
is not found, it says so and exits.

## Install

```sh
/plugin marketplace add KiwiCanopy/KiwiDesk-Claude
/plugin install kiwidesk@kiwidesk
```

## Privacy Policy

The plugin and KiwiDesk's MCP server run entirely on your Mac and send
nothing anywhere. What Claude reads through the tools — your Spaces,
windows and their titles, your settings — is sent to the model by
Claude Code, under Anthropic's own terms. KiwiDesk's full privacy
policy: <https://kiwidesk.kiwicanopy.com/privacy>.

## Support

Report a problem or ask a question in
[KiwiDesk's issues](https://github.com/KiwiCanopy/KiwiDesk/issues).
Report a security vulnerability as
[SECURITY.md](https://github.com/KiwiCanopy/KiwiDesk/blob/main/SECURITY.md)
describes.

## License

KiwiDesk is source-available under the Business Source License 1.1;
see [LICENSE](https://github.com/KiwiCanopy/KiwiDesk/blob/main/LICENSE).
