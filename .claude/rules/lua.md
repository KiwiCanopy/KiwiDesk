---
paths:
  - "Sources/KiwiDeskCore/Lua/**"
---

# Lua VM bridge

See AGENTS.md §5 for full rationale. When editing the Lua bridge:

- The runaway-script watchdog is an instruction-count hook; it
  **cannot** interrupt blocking C calls (`system()`, pipe reads),
  which run zero VM instructions and freeze the main thread
  forever. Never add an API that blocks in C on the main thread —
  external commands go through `ExecLauncher`.
- Lua registry refs (`luaL_ref`) are VM-specific and their slots
  are reused. Never deliver a ref into a different interpreter than
  minted it — capture the owning `LuaInterpreter` weakly, as
  `KiwiCore+ExecAPI` does.
