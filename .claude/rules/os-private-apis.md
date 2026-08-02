---
paths:
  - "Sources/KiwiDeskCore/OS/**"
  - "**/SkyLight*.swift"
  - "Sources/KiwiDeskCore/AX/AXHelper.swift"
---

# OS layer — private SkyLight/CGS APIs

Canonical for this subsystem (AGENTS.md §5 indexes it). When
editing here:

- Resolve private SkyLight/CGS symbols at runtime via `dlsym`
  (`SkyLight.swift`). **Never** link them with `@_silgen_name` — a
  linked symbol that disappears in a macOS update crashes the app
  at launch; a failed `dlsym` lookup returns nil and falls back.
- One symbol is exempt, and the exemption does not generalise:
  `_AXUIElementGetWindow`, linked with `@_silgen_name` in
  `AX/AXHelper.swift`. It is a stable Accessibility symbol, not
  SkyLight/CGS — the crash argument above is about the private
  window-server surface, which churns across releases. Do not read
  it as licence for a second linked symbol, and do not "fix" this
  one to `dlsym`. This file's `paths:` reaches `AXHelper.swift`
  precisely so the exemption arrives with the rule; a reviewer
  looking only at `accessibility.md` would see neither.
- **Every** private fast path must have a public-API fallback
  (`AXUIElement`). No fallback = not acceptable.
- Never disable SIP, and never ask the user to.
