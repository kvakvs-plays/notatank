---@type string, NotAddon
local addonName, addon = ...

local AceAddon = LibStub("AceAddon-3.0")

--- @class NotAddon
--- @field RAID_MARKS table<NotRaidmark>
--- @field RAID_MARK_ORDER table<number>
--- @field ADDON_NAME string
--- @field DISPLAY_NAME string
--- @field MACRO_OWNER_MARKER string
--- @field MACRO_MAX_BODY_LENGTH number
--- @field POPUP_BUTTON_COUNT number
--- @field REMINDER_TARGET_BUTTON_COUNT number
--- @field REMINDER_SHOUT_BUTTON_COUNT number

AceAddon:NewAddon(addon, addonName, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")

local version = "2026.6.0"
addon.ADDON_NAME = addonName
addon.DISPLAY_NAME = "Notatank"

function addon:OnInitialize()
	self:InitializeConfig()
	self:InitializeMacro()
	self:InitializeTargets()
	self:InitializePopup()
	self:InitializeReminders()
	self:InitializeOptions()
	self:InitializeCommands()
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "HandlePlayerRegenEnabled")
	self:RegisterEvent("PLAYER_REGEN_DISABLED", "HandlePlayerRegenDisabled")

	if self:IsDebugEnabled() then
		self:Print("loaded")
	end
end

function addon:HandlePlayerRegenEnabled()
	if self.HandleMacroRegenEnabled then
		self:HandleMacroRegenEnabled()
	end
	if self.HandlePopupRegenEnabled then
		self:HandlePopupRegenEnabled()
	end
	if self.HandleRemindersRegenEnabled then
		self:HandleRemindersRegenEnabled()
	end
end

function addon:HandlePlayerRegenDisabled()
	if self.HandlePopupRegenDisabled then
		self:HandlePopupRegenDisabled()
	end
	if self.HandleRemindersRegenDisabled then
		self:HandleRemindersRegenDisabled()
	end
end
