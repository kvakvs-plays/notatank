# Notatank File Map

## Root

- `Notatank-BCC.toc` - Classic TBC addon manifest. Loads embedded Ace3 libraries from `lib/`, declares `NotatankDB`, and loads source modules from `src/`.
- `wowaddon.py` - Standard-library packaging helper with `install` and `zip` commands for addon-only runtime files.
- `install.bat` - Windows helper that installs the addon into the configured local WoW `_anniversary_` AddOns folder.
- `release.bat` - Windows helper that writes a release zip to `../_Releases`.
- `AGENTS.md` - Repository instructions for agents.
- `impl.md` - Step-by-step implementation plan.
- `plan.md` - Feature plan and assumptions.

## Source

- `src/Core.lua` - Creates the AceAddon instance, stores addon display constants, and runs module initialization from `OnInitialize`.
- `src/Config.lua` - Owns AceDB defaults, initializes `NotatankDB`, and exposes profile/debug helpers.
- `src/Targets.lua` - Owns raid mark metadata, target priority entry normalization, add/remove/reorder helpers, current-target name capture, mouseover hostile target capture, captured-target sorting/filtering, and target status summaries.
- `src/Macro.lua` - Owns macro constants, pure macro rendering, addon-owned macro discovery/creation/update, combat queueing, truncation/full-slot feedback, and macro status state.
- `src/Popup.lua` - Owns the fixed secure target button pool, out-of-combat button preparation, secure combat visibility, drag positioning, scale, and popup lock state.
- `src/Auras.lua` - Owns cached unit-token aura snapshots and Classic-compatible helpful/harmful aura lookup helpers for reminder logic.
- `src/Reminders.lua` - Owns combat-safe passive class debuff and self-buff reminder icons, form checks, drag positioning, scale, opacity, and reminder lock state.
- `src/Options.lua` - Registers the AceConfig/AceConfigDialog options UI with editable target priority controls plus `Macro`, `Reminders`, read-only `Help`, and `Profiles` tabs.
- `src/Commands.lua` - Registers `/notatank` and `/nt`; opens options by default and handles `target`, `rebuild`, expanded diagnostics `status`, `lock`, `unlock`, and unknown-command help.

## Libraries

- `lib/` - Embedded Ace3 and related libraries used by the addon.
