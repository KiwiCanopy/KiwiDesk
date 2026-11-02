---
title: Actions
description: The actions KiwiDesk can run from a key.
---

# Actions

Each action below can be bound to a key with `bind`. The link opens its arguments in the [Lua reference](lua-reference.md). Settings and queries are listed by `kiwidesk list_commands --kind setting` and `--kind query` ([CLI & IPC](cli.md#discovering-commands)).

## KiwiDesk

| Action | What it does |
|---|---|
| [`focus`](lua-reference.md#focus) | Moves keyboard focus to the neighboring window. |
| [`swap`](lua-reference.md#swap) | Swaps the focused or named window with a neighbor; ids in place of direction swap two windows. |
| [`swap_here`](lua-reference.md#swap_here) | Brings the window an id names into your slot and focuses it; yours takes its place. |
| [`focus_window`](lua-reference.md#focus_window) | Focuses a window by id, switching to its Space where another Space holds it. |
| [`focus_space`](lua-reference.md#focus_space) | Switches to a Space, hiding the current Space's windows. |
| [`focus_space_back`](lua-reference.md#focus_space_back--focus_space_forward) | Goes back to the Space shown before, along the history space_history names. |
| [`focus_space_forward`](lua-reference.md#focus_space_back--focus_space_forward) | Goes forward again along the Space history, after focus_space_back. |
| [`focus_space_previous`](lua-reference.md#focus_space_previous--focus_space_next) | Switches to the previous Space in the focused screen's order, stopping at the first. |
| [`focus_space_next`](lua-reference.md#focus_space_previous--focus_space_next) | Switches to the next Space in the focused screen's order, stopping at the last. |
| [`focus_display_last`](lua-reference.md#focus_display_last--focus_display) | Goes to the screen you were on before, like Cmd-Tab for screens. |
| [`focus_display`](lua-reference.md#focus_display_last--focus_display) | Goes to the nearest screen in a direction, stopping at the last. |
| [`move_to_space`](lua-reference.md#move_to_space) | Moves the focused window, or the one a window id names, to a Space without following it. |
| [`move_to_space_and_follow`](lua-reference.md#move_to_space_and_follow) | Moves the focused window, or the one a window id names, to a Space and switches to it. |
| [`focus_desktop`](lua-reference.md#focus_desktop) | Switches to a macOS Desktop, exactly as a swipe would. |
| [`move_to_desktop`](lua-reference.md#move_to_desktop) | Moves the focused window to a macOS Desktop, and into a Space when one is named. |
| [`move_to_desktop_and_follow`](lua-reference.md#move_to_desktop_and_follow) | Moves the focused window to a macOS Desktop, into a Space when named, and follows it. |
| [`move_space_to_display`](lua-reference.md#move_space_to_display) | Moves a Space to another screen, named by number, fingerprint or name, and shows it there. |
| [`create_space`](lua-reference.md#create_space) | Makes a Space; temporary unless scope is profile, which may take the optional mode's place. |
| [`delete_space`](lua-reference.md#delete_space) | Removes a Space after rehoming its windows; scope profile removes it from the profile too. |
| [`make_floating`](lua-reference.md#make_floating) | Marks the focused window, or the one a window id names, as floating above the tiles. |
| [`make_tiled`](lua-reference.md#make_tiled) | Tiles the focused or named window; refused where a float rule or detection floats it. |
| [`toggle_floating`](lua-reference.md#toggle_floating) | Flips the focused or named window between floating and tiled, refused as make_tiled is. |
| [`new_window`](lua-reference.md#new_window) | Asks the focused or named window's app for a new window; success means asked. |
| [`close_window`](lua-reference.md#close_window) | Presses the focused or named window's close button; success means asked. |
| [`make_sticky`](lua-reference.md#make_sticky) | Marks the focused window globally sticky across all screens. |
| [`make_display_sticky`](lua-reference.md#make_display_sticky) | Marks the focused window sticky to its home screen. |
| [`make_unsticky`](lua-reference.md#make_unsticky) | Clears the focused window's sticky state. |
| [`toggle_sticky`](lua-reference.md#toggle_sticky) | Flips the focused window between globally sticky and off. |
| [`toggle_display_sticky`](lua-reference.md#toggle_display_sticky) | Flips the focused window between screen-sticky and off. |
| [`toggle_maximized`](lua-reference.md#toggle_maximized) | Fills the screen with the focused tiled window until pressed again or focus moves on. |
| [`pocket`](lua-reference.md#pocket) | Pockets or takes out the next pocket window, or pockets the window an id names. |
| [`toggle_pocket_window`](lua-reference.md#toggle_pocket_window) | Marks the focused or named window as the pocket window, floating it, or unmarks it, tiling it. |
| [`pocket_app`](lua-reference.md#pocket_app) | Takes an app's own pocket window out or puts it away, or opens a new window of the app there. |
| [`override_sticky_reach`](lua-reference.md#override_sticky_reach) | Overrides Desktop reach for the focused sticky window; auto follows sticky.set_desktop_reach. |
| [`resize`](lua-reference.md#resize) | Resizes the focused window along the x or y axis. |
| [`move_to_track`](lua-reference.md#move_to_track) | Moves the focused window one track along; takes prev or next. |
| [`focus_or_spawn`](lua-reference.md#focus_or_spawn) | Focuses an app's window, or launches a new instance. |
| [`spawn_new`](lua-reference.md#spawn_new) | Launches a new instance of an app by bundle identifier. |
| [`gather`](lua-reference.md#gather) | Moves every window of an app into the Space you are on, from other Desktops too. |
| [`move_here`](lua-reference.md#move_here) | Moves an app's most recently focused window into the Space you are on, or opens the app. |
| [`set_mode`](lua-reference.md#set_mode) | Sets a Space's layout mode; omit the Space to set the active one. |
| [`cycle_mode`](lua-reference.md#cycle_mode) | Moves the focused Space to the next layout in the cycle list, or the previous one. |
| [`reset_layout_sizing`](lua-reference.md#reset_layout_sizing) | Undoes manual resizes back to the profile: the active Space, one by id, or every one with `all`. |
| [`debug_log`](lua-reference.md#debug_log) | Writes a message to the unified log. |
| [`reload_config`](lua-reference.md#reload_config) | Reloads the configuration file from disk. |
| [`save_profile`](lua-reference.md#save_profile-load_profile-delete_profile-set_default_profile) | Saves the current configuration to a profile, which claims the connected screen setup. |
| [`load_profile`](lua-reference.md#save_profile-load_profile-delete_profile-set_default_profile) | Loads a profile, claiming the connected screen setup where its screen count fits. |
| [`delete_profile`](lua-reference.md#save_profile-load_profile-delete_profile-set_default_profile) | Deletes a saved profile. |
| [`exec`](lua-reference.md#kiwideskexec) | Runs a shell command in the background, calling back when it exits. |
| [`switch_layer`](lua-reference.md#switch_layer) | Makes a defined keybinding layer the active one. |
| [`open_settings`](lua-reference.md#open_settings) | Opens the Settings window and brings it to the front. |

## app_bar

| Action | What it does |
|---|---|
| [`app_bar.toggle_reveal`](lua-reference.md#app_bartoggle_reveal) | Shows or hides the App Bar over the windows on the active Space's screen. |

## kiwihub

| Action | What it does |
|---|---|
| [`kiwihub.show`](lua-reference.md#kiwihubshow) | Opens KiwiHub on a side, switches it there, or closes it if that side is open. |

## kiwivision

| Action | What it does |
|---|---|
| [`kiwivision.toggle`](lua-reference.md#kiwivisiontoggle) | Turns KiwiVision on or off; named, turns that lens on, or off while it is on. |

## space_bar

| Action | What it does |
|---|---|
| [`space_bar.toggle_reveal`](lua-reference.md#space_bartoggle_reveal) | Shows or hides the Space Bar over the windows on the active Space's screen. |

## stack

| Action | What it does |
|---|---|
| [`stack.promote`](lua-reference.md#stackpromote) | Moves the focused window to the master zone. |
| [`stack.demote`](lua-reference.md#stackdemote) | Moves the focused window out of the master zone. |
| [`stack.toggle_stack_position`](lua-reference.md#stacktoggle_stack_position) | Flips a Space's stack zone to the other side on the Desktop shown now, for the session. |

## track

| Action | What it does |
|---|---|
| [`track.swap`](lua-reference.md#trackswap) | Swaps the focused window's track with the next one along; takes prev or next. |

