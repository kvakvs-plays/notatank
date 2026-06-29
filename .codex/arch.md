# Notatank Architecture

Notatank is a World of Warcraft Classic TBC addon built around Ace3. The addon currently implements the minimal loadable foundation from implementation steps 1 through 3: lifecycle setup, saved profile defaults, slash command routing, and an AceConfig options shell.

## Load Order

`Notatank-BCC.toc` embeds the required Ace3 libraries from `lib/` before loading addon modules from `src/`.

1. `src/Core.lua` creates the AceAddon instance on the shared addon namespace table.
2. `src/Config.lua` defines AceDB defaults and initializes `NotatankDB`.
3. `src/Options.lua` registers the AceConfig options table and Interface Options entry.
4. `src/Commands.lua` registers `/notatank` and `/nt`.

## Runtime Shape

The addon namespace table is also the AceAddon object. Modules attach methods to that table and avoid globals. `Core.lua` calls module initialization methods from `OnInitialize` after all source files have loaded.

Saved data is profile-scoped through AceDB. Current defaults include placeholder settings for target capture, macro ownership, reminder overlays, and AceDB profiles. These defaults are intentionally broader than the visible behavior so steps 4 and later can grow without changing the saved-variable root shape.

## Current Boundaries

No WoW macro writes, protected frame changes, targeting, or combat behavior exist yet. Slash commands and options only update saved settings or print status. Future macro and protected UI work should stay out of combat and queue updates until combat ends.

## Packaging

`wowaddon.py` packages only runtime addon files: `src/`, `lib/`, and root `.toc` files. `install` replaces the addon folder under a supplied WoW `Interface\AddOns` directory, and `zip` creates a release archive named from the checkout directory and the `local version = "..."` line in `src/Core.lua`.
