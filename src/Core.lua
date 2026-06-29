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

AceAddon:NewAddon(addon, addonName, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")

local version = "2026.6.0"
addon.ADDON_NAME = addonName
addon.DISPLAY_NAME = "Notatank"

function addon:OnInitialize()
	self:InitializeConfig()
	self:InitializeMacro()
	self:InitializeTargets()
	self:InitializeOptions()
	self:InitializeCommands()

	if self:IsDebugEnabled() then
		self:Print("loaded")
	end
end
