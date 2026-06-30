---@type string, NotAddon
local addonName, addon = ...

local commandHelp = {
	"Commands: (also read Help tab in the /nt options window)",
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

local function printLines(addonInstance, lines)
	for index = 1, #(lines or {}) do
		addonInstance:Print(lines[index])
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
	local popupState = self.GetPopupState and self:GetPopupState() or {}
	local reminderState = self.GetReminderState and self:GetReminderState() or {}

	self:Print(("target capture: %s"):format(profile.targets.captureEnabled and "enabled" or "disabled"))
	self:Print(("priority targets: %d"):format(priorityCount))
	if self.GetPriorityStatusLines then
		printLines(self, self:GetPriorityStatusLines(8))
	end
	self:Print(("captured targets: %d"):format(capturedCount))
	if self.GetCapturedTargetStatusLines then
		printLines(self, self:GetCapturedTargetStatusLines(8))
	end
	self:Print(("macro %s: %s"):format(macroState, profile.macro.name))
	if state.index then
		self:Print(("macro index: %d"):format(state.index))
	end
	if state.truncated then
		self:Print("macro body: truncated to fit the Classic macro limit")
	end
	if state.queued then
		self:Print("macro rebuild: queued until combat ends")
	elseif state.lastError then
		self:Print(("macro rebuild: %s"):format(state.lastError))
	else
		self:Print("macro rebuild: ready")
	end
	self:Print(("popup: %s, %d buttons prepared"):format(popupState.locked and "locked" or "unlocked", popupState.preparedCount or 0))
	if popupState.queued then
		self:Print("popup update: queued until combat ends")
	else
		self:Print("popup update: ready")
	end
	self:Print(("reminders: %s, target missing %d, shout %s"):format(
		reminderState.locked and "locked" or "unlocked",
		reminderState.targetMissingCount or 0,
		reminderState.shoutActive and "active" or "inactive"
	))
	if reminderState.queued then
		self:Print("reminder update: queued until combat ends")
	else
		self:Print("reminder update: ready")
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
	if self.SetPopupLocked then
		self:SetPopupLocked(locked)
	end
	if self.SetRemindersLocked then
		self:SetRemindersLocked(locked)
	end
	self:Print(("Notatank frames are %s."):format(profile.overlays.locked and "locked" or "unlocked"))
end
