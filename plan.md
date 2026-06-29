# Notatank Feature Plan

## Summary
Build the first functional addon architecture around two workflows: priority raid-mark target capture/targeting, and tank reminder overlays. Use Ace3 for lifecycle, saved profiles, options, timers, and slash commands. Store all player choices in AceDB profiles, defaulting to manual per-profile configuration, selected-mark mouseover capture, class-based reminders, combat-only popup visibility, exact-name macro rendering, and one priority reminder icon per overlay.

## Key Changes
- Add core addon modules under `src/` and load them from `Notatank-BCC.toc`: core lifecycle/config, options, slash commands, target assignment/capture, macro management, secure target popup, reminder overlays, and version/API helpers.
- Create `.codex/arch.md` and `.codex/map.md`, and keep them updated with the new architecture and module map.
- Add an AceConfig options window with tabs for:
  - `Targets`: Two lists: one with eight raid marks and another list containing selected raid mark or string monster names. Priority order controls: up and down button, delete button, add current target button, and add string name (text input and add button) for monster name entered by player.
    - Priority targets can also be string names of monsters entered manually by the player, or added by targeting a mob and typing `/nt target`.
    - Priority targets can be moved up and down using prio up and prio down buttons.
    - Adding a string name or targeted mob 
  - `Macro`: configurable macro name defaulting to `Notatank`, enable/disable macro maintenance, and priority behavior using the configured raid-mark order.
  - `Reminders`: Overlay image/button control, locked/unlocked drag mode, preset anchor positions, scale, opacity, and class reminder enablement. Each reminder for each class has a checkbox to enable the debuff checking. The protected button to cast each of the debuffs in combat should be pre-created and hidden.
  - `Profiles`: AceDB profile controls.
- Add slash commands through AceConsole:
  - `/notatank` or `/nt` opens options.
  - `/notatank target` or `/nt target` adds currently targeted mob to priority list in options as first (top prio).
  - `/notatank status` (or `/nt status`) prints selected marks, captured target count, macro name, and overlay mode.
  - `/notatank lock` and `/notatank unlock` (or `/nt lock` | `/nt unlock`) control Reminders overlay/buttons dragging. Add mention to the `Reminders` options tab, so that the user knows these commands exist.

## Target Capture, Popup, And Macro
- Before combat, mouseover hostile units with selected raid marks are captured into an in-memory candidate list keyed by unit GUID when available, falling back to normalized name.
- Captured targets store name, raid mark, priority rank, last seen time, and dead/hostile validity when available.
- The combat popup is a secure clickable button list shown only in combat when candidates exist; button order follows selected raid-mark priority, then most recently seen within the same mark.
- Secure button attributes are only created or changed out of combat. If target data changes during combat, queue updates until `PLAYER_REGEN_ENABLED`.
- The addon owns one macro by configured name. Out of combat, render it from captured candidates as ordered `/tar [nodead] <name>` lines followed by `/startattack`.
- If the macro body would exceed the Classic macro length limit, keep the highest-priority targets that fit and report truncation through addon chat output.
- Never overwrite unrelated macros. Only edit an existing macro with the configured name if it matches addon ownership tracking, using a saved macro id/name and an addon marker in the body where feasible.

## Reminder Overlays
- Add two movable frames: target debuff reminder and player shout reminder. Each can be positioned by preset or dragging while unlocked.
- Target debuff reminder is class-based:
  - Warrior: missing Thunder Clap or Demoralizing Shout on current hostile target.
  - Paladin: missing Judgement on current hostile target.
  - Druid in bear form: missing Faerie Fire, Demoralizing Roar or Mangle on current hostile target.
- Show (all enabled in options) missing debuff icons. Hide when no applicable hostile target exists or all tracked debuffs are present.
- Warrior shout reminder appears only in combat for warriors:
  - Show Battle Shout or Commanding Shout icon with countdown when the player’s own active shout is near expiry.
  - Show a missing-shout reminder if only another warrior’s shout is active and the player can apply their own.
  - Hide shout reminders after the player has shouted and the tracked buff is healthy.
- Use event-driven updates with AceEvent and throttled refreshes with AceTimer for noisy aura/target/combat changes.

## Public Interfaces And Saved Data
- Saved profile defaults:
  - `targets.enabledMarks`: map of raid mark id to boolean.
  - `targets.priority`: ordered raid mark id list. The list can also take monster names, entered by player or by targeting them and typing `/nt target`, this way the monster name will be added to target list and player can adjust its priority by clicking prio up/down buttons.
  - `macro.enabled`: true.
  - `macro.name`: default to `Notatank`.
  - `popup.locked`, `popup.point`, `popup.scale`.
  - `overlays.targetDebuffs.enabled`, `overlays.shouts.enabled`, `overlays.locked`, positions, scale, opacity.
- Internal module APIs:
  - `Targets:GetPriorityMarks()`, `Targets:GetCapturedTargets()`, `Targets:HandleMouseoverUnit(unit)`.
  - `Macro:EnsureMacro()`, `Macro:Rebuild()`, `Macro:Render(candidates)`.
  - `Popup:PrepareButtons(candidates)`, `Popup:SetLocked(locked)`.
  - `Reminders:RefreshTargetDebuffs()`, `Reminders:RefreshPlayerBuffs()`.

## Test Plan
- Run Lua syntax checks for all addon source files when `lua` or `luac` is available.
- In-game Classic TBC verification:
  - Options open from slash command and Interface Options.
  - Raid mark checkboxes persist across reloads and priority order changes popup/macro order.
  - Mouseover selected marked enemies before combat populates popup and macro.
  - Unselected marks are ignored.
  - Entering combat shows clickable secure target buttons without blocked-action errors.
  - Macro targets candidates in priority order and starts attack.
  - Macro rebuild is deferred if requested during combat.
  - Full macro slots and macro truncation produce clear user feedback.
  - Warrior, paladin, and bear druid reminder modes show only relevant icons.
  - Overlay drag/lock and preset positioning persist after reload.

## Assumptions
- V1 does not sync assignments between players; priorities are manual per profile.
- V1 captures only mouseover hostile units that have selected raid marks.
- Popup visibility defaults to combat-only.
- Macro targeting uses exact captured unit names and the user-requested `/tar [nodead] <name>` line format.
- Reminder overlays show one priority icon at a time rather than an icon row.
- If Classic TBC aura APIs do not reliably expose buff caster, warrior shout ownership uses best-effort tracking from the player’s own successful shout casts plus current aura state.
