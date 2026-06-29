---@type string, NotAddon
local addonName, addon = ...

local commandHelp = {
	"Commands:",
	"/nt or /notatank - open options",
	"/nt target - add your current target as top priority",
	"/nt rebuild - repair the addon macro",
	"/nt status - show current setup summary",
	"/nt lock - lock movable Notatank frames",
	"/nt unlock - unlock movable Notatank frames",
}

local function parseInput(input)
	input = input or ""
	local command, rest = input:match("^%s*(%S*)%s*(.-)%s*$")
	return (command or ""):lower(), rest or ""
end

function addon:InitializeCommands()
	self:RegisterChatCommand("notatank", "HandleChatCommand")
	self:RegisterChatCommand("nt", "HandleChatCommand")
end

function addon:HandleChatCommand(input)
	local command = parseInput(input)

	if command == "" then
		self:OpenOptions()
	elseif command == "target" then
		self:AddCurrentTargetCommand()
	elseif command == "rebuild" or command == "repair" then
		self:RebuildMacroCommand()
	elseif command == "status" then
		self:PrintStatus()
	elseif command == "lock" then
		self:SetOverlayLock(true)
	elseif command == "unlock" then
		self:SetOverlayLock(false)
	else
		self:PrintHelp()
	end
end

function addon:PrintHelp()
	for index = 1, #commandHelp do
		self:Print(commandHelp[index])
	end
end

function addon:PrintStatus()
	local profile = self:GetProfile()
	if not profile then
		self:Print("Saved settings are not ready.")
		return
	end

	local lockState = profile.overlays.locked and "locked" or "unlocked"
	local macroState = profile.macro.enabled and "enabled" or "disabled"
	local priorityCount = self.GetPriorityCount and self:GetPriorityCount() or 0
	local capturedCount = self.GetCapturedTargetCount and self:GetCapturedTargetCount() or 0
	local state = self.GetMacroState and self:GetMacroState() or {}

	self:Print(("macro %s: %s"):format(macroState, profile.macro.name))
	self:Print(("target capture: %s"):format(profile.targets.captureEnabled and "enabled" or "disabled"))
	self:Print(("priority targets: %d"):format(priorityCount))
	self:Print(("captured targets: %d"):format(capturedCount))
	if state.queued then
		self:Print("macro rebuild: queued until combat ends")
	elseif state.lastError then
		self:Print(("macro rebuild: %s"):format(state.lastError))
	elseif state.index then
		self:Print(("macro index: %d"):format(state.index))
	end
	self:Print(("overlays: %s"):format(lockState))
end

function addon:RebuildMacroCommand()
	local ok, message = self:RequestMacroRebuild("manual command")
	if ok then
		self:Print("Macro repaired.")
	elseif message then
		self:Print(message)
	end
end

function addon:AddCurrentTargetCommand()
	local ok, indexOrMessage, label = self:AddCurrentTargetToPriority(true)
	if ok then
		self:Print(("Added top priority target: %s."):format(label))
	else
		self:Print(indexOrMessage)
	end
end

function addon:SetOverlayLock(locked)
	local profile = self:GetProfile()
	if not profile then
		self:Print("Saved settings are not ready.")
		return
	end

	profile.overlays.locked = locked and true or false
	self:Print(("Notatank frames are %s."):format(profile.overlays.locked and "locked" or "unlocked"))
end
