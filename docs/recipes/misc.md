---
title: Miscellaneous Integrations
description: Shell scripts, event streaming, Hammerspoon, and
  per-desktop keybindings.
---

# Miscellaneous Integrations

## Shell scripts & event streaming

Any process can subscribe to KiwiDesk events as newline-delimited
JSON:

```sh
KIWIDESK=~/.build/release/KiwiDesk

"$KIWIDESK" subscribe space_change | while read -r line; do
    space=$(echo "$line" | jq -r '.data.space_id')
    echo "switched to space $space"
done
```

Query state on demand:

```sh
# List all spaces and their layout modes:
"$KIWIDESK" get_state | jq '.spaces[] | {id, mode}'

# List monitors:
"$KIWIDESK" list_monitors | jq
```

The event stream is useful for durable external daemons, shell
functions, or tools that run in a different sandbox than
KiwiDesk. Each event has a `type` (e.g., `"space_change"`) and
a `data` object with fields matching the Lua callback arguments
(e.g., `space_id`, `mode`).

## Hammerspoon

Drive KiwiDesk from Hammerspoon (or vice versa) through the CLI.
Point `KIWIDESK` at your build (it is not on `PATH` before 1.0 —
see the [recipes intro](index.md)); swap it for plain `kiwidesk`
once the Homebrew cask symlinks it:

```lua
local KIWIDESK = os.getenv("HOME")
    .. "/path/to/KiwiDesk/.build/release/KiwiDesk"

hs.hotkey.bind({"cmd", "alt"}, "m", function()
    os.execute("'" .. KIWIDESK .. "' set_mode monocle")
end)
```

Or set up space switching via KiwiDesk:

```lua
hs.hotkey.bind({"cmd", "alt"}, "1", function()
    os.execute("'" .. KIWIDESK .. "' focus_virtual_space 1")
end)
```

**Tip:** KiwiDesk's own modal keybindings (see
[configuration](../lua-reference.md)) cover most Hammerspoon
window-management use cases natively, and they do not require
another daemon. If you are already running Hammerspoon for
other reasons, the CLI bridge above lets you invoke KiwiDesk
commands without duplicating logic.

## Per-desktop keybindings (hand-written configs)

> **Native support exists now:** A profile can carry a sparse
> `"modes"` override that shadows individual base shortcuts.
> Combined with `bind_profile_to_native_space`, each desktop
> gets its own layouts and its own keybinds with no Lua code.
> See *Config cascade* under
> [Keybindings](../lua-reference.md). This recipe remains for
> hand-written (non-GUI-managed) configs, where Lua owns all
> keybindings.

For a hand-written config, combine modal modes with the
`native_space_change` event. Only the active mode's bindings
fire, so build each desktop's mode by merging shared binds with
per-desktop overrides:

```lua
-- Shared binds, active in every mode:
local common = {
    ["cmd+alt+1"] = function()
        KiwiDesk.focus_virtual_space("1")
    end,
    ["cmd+alt+2"] = function()
        KiwiDesk.focus_virtual_space("2")
    end,
    ["cmd+alt+left"] = function()
        KiwiDesk.focus("left")
    end,
    ["cmd+alt+right"] = function()
        KiwiDesk.focus("right")
    end,
    -- ... other shared binds
}

-- Helper: merge common binds with per-mode overrides.
local function mode(overrides)
    local merged = {}
    for k, v in pairs(common) do
        merged[k] = v
    end
    for k, v in pairs(overrides) do
        merged[k] = v
    end
    return merged
end

-- Desktop 1: standard binds, no overrides.
KiwiDesk.define_mode("desk1", mode({}))

-- Desktop 2: override cmd+alt+m to enter monocle mode.
KiwiDesk.define_mode("desk2", mode({
    ["cmd+alt+m"] = function()
        KiwiDesk.set_mode("monocle")
    end,
}))

-- Switch mode when native macOS desktop changes.
KiwiDesk.on("native_space_change", function(n)
    KiwiDesk.switch_mode(n == 2 and "desk2" or "desk1")
end)

-- Start on desktop 1.
KiwiDesk.switch_mode("desk1")
```

Pair this with `bind_profile_to_native_space` (see
[configuration](../lua-reference.md)) and each desktop gets
its own layouts *and* its own keybinds.
