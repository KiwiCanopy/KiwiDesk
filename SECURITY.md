# Security Policy

## Reporting a Vulnerability

Please **do not** open a public issue for security problems.

Instead, use GitHub's private vulnerability reporting
("Security" tab → "Report a vulnerability") on this
repository. You will get an acknowledgement within a few days.

Please include reproduction steps, the affected version or
commit, and your macOS version.

## Supported Versions

During the beta, only the latest `main` is supported. Fixes
land there first.

## Scope & Design Notes

Facts that matter when assessing KiwiDesk's attack surface:

- KiwiDesk runs entirely in **user-space** and never asks you
  to disable System Integrity Protection.
- The only required permission is **Accessibility** (to move
  and resize windows). KiwiDesk never requests Input
  Monitoring; global hotkeys use the Carbon API, which does
  not observe keystrokes.
- The **IPC socket** (`~/.config/KiwiDesk/KiwiDesk.sock`) is a
  UNIX domain socket in the user's home directory, reachable
  only by processes of the same user. Anything reachable over
  it can rearrange windows and read window titles — the same
  power any process of your user already has via init.lua.
- **init.lua runs with full Lua stdlib** (including
  `os.execute`) because it is the user's own configuration,
  equivalent to a shell profile. The 500 ms sandbox timeout
  protects against hangs, not against malicious configs — do
  not paste configs you do not understand.
- Private macOS APIs (SkyLight) are resolved at runtime and
  fall back to the public Accessibility API when unavailable.
