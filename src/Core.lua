local addonName, addon = ...

local AceAddon = LibStub("AceAddon-3.0")

AceAddon:NewAddon(addon, addonName, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")

addon.ADDON_NAME = addonName
addon.DISPLAY_NAME = "Notatank"

function addon:OnInitialize()
	self:InitializeConfig()
	self:InitializeOptions()
	self:InitializeCommands()

	if self:IsDebugEnabled() then
		self:Print("loaded")
	end
end
