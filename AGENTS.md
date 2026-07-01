# AGENTS.md

Guidance for agents working on Notatank, a World of Warcraft addon written in Lua.

## Project Scope

- Target World of Warcraft Classic TBC `2.5.5` and later compatible clients first.
- Keep compatibility boundaries explicit. If support for other WoW versions is added later, isolate version-specific API differences behind small helper functions or modules.
- The addon uses the Ace3 addon suite for addon lifecycle, saved variables, options UI, events, timers, slash command integration, and related utility work.
- Core addon behavior includes:
  - An options window.
  - Slash commands.
  - A managed custom macro owned by the addon.
  - Updating that macro's contents when tank targets change.

## Development Principles

- Lua is currently installed on development machine, the OS is Windows, you're welcome to use lua for syntax checking.
- Prefer small, local Lua modules with clear ownership over large shared files. The source root is `src/`, the 3rd party libraries root is `lib/`.
- Keep WoW API calls at the edges where practical, especially for macro management, group/raid inspection, target resolution, and UI setup.
- Avoid global variables. Use one addon namespace table and local module tables.
- Do not introduce dependencies outside Ace3 unless there is a clear addon-facing benefit.
- Keep behavior deterministic and conservative around protected actions, combat lockdown, and macro updates.
- Treat saved variables as a migration boundary. Add defaults and migration code when changing saved data shape.
- Maintain current addon architecture in `.codex/arch.md` and if something changes - keep this file updated.
- Maintain current module brief descriptions and file map in `.codex/map.md` and if something changes, if files are created, renamed or deleted - keep this file updated.
- For new code maintain a comment before each function or important class/struct/enum with the intent why this exists.
  - For modified code if such comment is missing, update it.

## Ace3 Usage

- Ace3 libraries are located under `lib/` and there are:
  - !LibUIDropDownMenu
  - AceAddon-3.0. Use `AceAddon-3.0` for addon creation and lifecycle methods such as `OnInitialize`, `OnEnable`, and `OnDisable`.
  - AceBucket-3.0
  - AceComm-3.0
  - `AceConsole-3.0` - for slash command registration and command parsing.
  - AceConfig-3.0 contains inside a sublibraries: 
    - AceConfigCmd-3.0
    - AceConfigDialog-3.0
    - AceConfigDropdown-3.0
    - AceConfigRegistry-3.0
    - AceDBOptions-3.0
    - Use `AceConfig-3.0`, `AceConfigDialog-3.0`, and `AceDBOptions-3.0` for options UI.
  - Use `AceDB-3.0` for saved variables and profiles.
  - `AceEvent-3.0` for WoW events instead of raw frame event plumbing unless there is a specific reason.
  - AceGUI-3.0
  - AceHook-3.0
  - AceLocale-3.0
  - AceSerializer-3.0
  - AceTab-3.0
  - Use `AceTimer-3.0` for delayed or throttled updates instead of ad hoc elapsed-time frames.
  - CallbackHandler-1.0
  - LibDBIcon-1.0
  - LibStub
- Keep Ace3 option tables declarative and stable. Avoid building large option trees repeatedly at runtime.

## WoW Classic Compatibility

- Code for the Classic TBC API surface unless a file or module is explicitly version-gated.
- Before using newer retail APIs, confirm they exist in Classic TBC or guard them.
- Avoid assuming modern macro, specialization, group finder, or unit API behavior from retail.
- Keep `.toc` interface versions and metadata clear when version support changes.
- Do not use APIs that are blocked in combat for protected actions. If a requested update cannot run in combat, queue it and apply it after `PLAYER_REGEN_ENABLED`.

## Macro Management

- The addon owns and maintains one custom macro. Keep the macro name/body constants centralized.
- Never overwrite unrelated player macros.
- Before creating a macro, search for the addon's existing macro by name.
- Before editing a macro, confirm it is the addon-owned macro. If ownership needs to be tracked, store addon-specific markers in the macro body or saved variables.
- Macro updates should be idempotent. Re-running the update with the same tank targets should not churn the macro.
- Respect macro length limits. When target data is too large, choose a predictable fallback rather than producing a broken macro.
- Handle full macro slots gracefully with a user-visible warning through the addon console or UI.
- Avoid macro writes during combat lockdown when the client disallows them. Queue the desired body and retry when combat ends.

## Tank Target Handling

- Keep tank target discovery separate from macro rendering.
- Normalize tank target data before rendering the macro.
- Expect missing, offline, dead, out-of-range, cross-realm, or unresolvable units.
- Avoid frequent macro rewrites from noisy events. Throttle or coalesce updates using AceTimer.
- Prefer explicit user actions or meaningful group/role/target events over constant polling.

## Options Window

- Register options through AceConfig and AceConfigDialog.
- Keep option keys stable once released because saved profiles may refer to them.
- Provide defaults through AceDB rather than scattered nil checks.
- Use clear option names and descriptions in UI strings.
- If localization is added, keep user-facing strings in one place.

## Slash Commands

- Register slash commands through AceConsole.
- Provide commands for at least:
  - Opening options.
  - Rebuilding or repairing the addon macro.
  - Printing current status.
  - Resetting settings, if implemented.
- Command handlers should validate input and print concise feedback.
- Keep command names and aliases documented in code comments or a user-facing help command.

## File Organization

Suggested structure when adding implementation files:

```text
Notatank.toc
Core.lua
Config.lua
Options.lua
Commands.lua
Macro.lua
Tanks.lua
Version.lua
Libs/
```

- `Core.lua`: addon creation, lifecycle, module registration.
- `Config.lua`: defaults, saved variable setup, migrations.
- `Options.lua`: AceConfig option table and options window registration.
- `Commands.lua`: slash commands and command help.
- `Macro.lua`: macro discovery, creation, rendering, updates, combat queueing.
- `Tanks.lua`: tank target discovery and normalization.
- `Version.lua`: client/version checks and compatibility helpers.

Adjust this structure if the repository establishes a different pattern later.

## Testing and Verification

- Syntax-check Lua files before finishing when a Lua interpreter or luac is available.
- Prefer focused manual test notes for WoW-client behavior that cannot be automated locally.
- Verify macro flows in-game for:
  - First install with no existing macro.
  - Existing addon macro.
  - Full macro slots.
  - Group changes.
  - Tank target changes.
  - In-combat updates and post-combat retry.
  - Options profile changes.
- Do not treat a clean Lua syntax check as proof of WoW API compatibility.

## Coding Style

- Use Lua locals aggressively: `local addonName, addon = ...`.
- Keep functions short and named around addon behavior.
- Prefer table-driven mappings over long conditional chains when handling commands or options.
- Use `string.format` for generated macro bodies when it improves readability.
- Keep comments focused on WoW API constraints, combat lockdown, compatibility decisions, and non-obvious macro behavior.
- Avoid broad formatting churn in unrelated files.

## Release Notes

- When changing behavior, update any changelog or release notes if present.
- Call out compatibility changes, saved variable migrations, slash command changes, and macro behavior changes.
- Keep packaging assumptions explicit, especially whether Ace3 is embedded under `Libs/` or loaded as an external dependency.
