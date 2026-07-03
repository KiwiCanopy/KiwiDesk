# CLua — vendored Lua 5.4.8

Unmodified upstream Lua 5.4.8 sources from
https://www.lua.org/ftp/lua-5.4.8.tar.gz (MIT license, see
LICENSE).

**Do not edit files in `src/`.** To upgrade, replace `src/` and
`include/` with the new upstream release and rebuild.

Local additions (ours, not upstream):
- `include/CLuaShim.h` — static-inline wrappers for Lua C
  macros that Swift cannot import directly.

The standalone interpreter entry points (`lua.c`, `luac.c`) are
intentionally excluded — KiwiDesk embeds the VM.
