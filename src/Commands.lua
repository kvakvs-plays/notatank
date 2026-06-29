local addonName, addon = ...

local commandHelp = {
	"Commands:",
	"/nt or /notatank - open options",
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

	self:Print(("macro %s: %s"):format(macroState, profile.macro.name))
	self:Print(("target capture placeholder: %s"):format(profile.targets.captureEnabled and "enabled" or "disabled"))
	self:Print(("overlays: %s"):format(lockState))
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
