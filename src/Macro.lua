---@type string, NotAddon
local addonName, addon = ...

local OWNER_MARKER = "# Notatank:owned"
local DEFAULT_ICON = "INV_MISC_QUESTIONMARK"
local MAX_BODY_LENGTH = 255

addon.MACRO_OWNER_MARKER = OWNER_MARKER
addon.MACRO_MAX_BODY_LENGTH = MAX_BODY_LENGTH

local macroState = {
	index = nil,
	queued = false,
	lastError = nil,
	truncated = false,
}

local function isInCombat()
	return type(InCombatLockdown) == "function" and InCombatLockdown()
end

local function getMacroName()
	local profile = addon:GetProfile()
	local name = profile and profile.macro and profile.macro.name
	if type(name) ~= "string" or name:match("^%s*$") then
		return "Notatank"
	end

	return name:match("^%s*(.-)%s*$")
end

local function macroIsEnabled()
	local profile = addon:GetProfile()
	return profile and profile.macro and profile.macro.enabled
end

local function shouldRebuildOnChanges(reason)
	local profile = addon:GetProfile()
	if reason == "priority changed" or reason == "captured mouseover target" or reason == "captured target died" then
		return not profile or not profile.macro or profile.macro.rebuildOnChanges ~= false
	end

	return true
end

local function bodyHasMarker(body)
	return type(body) == "string" and body:find(OWNER_MARKER, 1, true) ~= nil
end

local function uniqueCandidateNames(candidates)
	local names = {}
	local seen = {}

	for index = 1, #(candidates or {}) do
		local candidate = candidates[index]
		local name = candidate and candidate.name
		if type(name) == "string" and name ~= "" then
			local key = name:lower()
			if not seen[key] then
				seen[key] = true
				names[#names + 1] = name
			end
		end
	end

	return names
end

local function renderLines(candidates)
	local lines = {}
	local names = uniqueCandidateNames(candidates)

	for index = 1, #names do
		lines[#lines + 1] = ("/tar [nodead] %s"):format(names[index])
	end

	lines[#lines + 1] = "/startattack"
	return lines
end

local function joinLines(lines)
	return table.concat(lines, "\n")
end

local function renderWritableBody(candidates)
	local lines = { OWNER_MARKER }
	local truncated = false
	local targetLines = renderLines(candidates)

	for index = 1, #targetLines do
		local line = targetLines[index]
		if line == "/startattack" then
			break
		end

		local candidateLines = {}
		for lineIndex = 1, #lines do
			candidateLines[lineIndex] = lines[lineIndex]
		end
		candidateLines[#candidateLines + 1] = line
		candidateLines[#candidateLines + 1] = "/startattack"

		if #joinLines(candidateLines) <= MAX_BODY_LENGTH then
			lines[#lines + 1] = line
		else
			truncated = true
		end
	end

	lines[#lines + 1] = "/startattack"

	return joinLines(lines), truncated
end

local function findOwnedMacro()
	if type(GetMacroIndexByName) ~= "function" then
		return nil, nil, "Macro API is not available."
	end

	local name = getMacroName()
	local index = GetMacroIndexByName(name)
	if not index or index == 0 then
		return nil, name
	end

	if type(GetMacroInfo) ~= "function" then
		return nil, name, "Macro API is not available."
	end

	local macroName, icon, body = GetMacroInfo(index)
	if not bodyHasMarker(body) then
		return nil, name, ("A macro named %s already exists and is not owned by Notatank."):format(name)
	end

	return {
		index = index,
		name = macroName or name,
		icon = icon or DEFAULT_ICON,
		body = body or "",
	}, name
end

local function storeMacroIndex(index, name)
	local profile = addon:GetProfile()
	if profile and profile.macro then
		profile.macro.ownedIndex = index
		profile.macro.ownedName = name
	end
	macroState.index = index
end

local function reportOnce(message)
	if macroState.lastError ~= message then
		addon:Print(message)
	end
	macroState.lastError = message
end

function addon:InitializeMacro()
	self:RequestMacroRebuild("addon loaded")
end

function addon:RenderMacro(candidates)
	return joinLines(renderLines(candidates))
end

function addon:GetRenderedMacroPreview()
	local candidates = self.GetCapturedTargets and self:GetCapturedTargets() or {}
	return self:RenderMacro(candidates)
end

function addon:GetMacroState()
	return macroState
end

function addon:RequestMacroRebuild(reason)
	if not macroIsEnabled() then
		macroState.queued = false
		return false, "Macro maintenance is disabled."
	end

	if not shouldRebuildOnChanges(reason) then
		return false, "Automatic macro rebuilds are disabled."
	end

	if isInCombat() then
		macroState.queued = true
		return false, "Macro rebuild queued until combat ends."
	end

	return self:EnsureMacro(reason)
end

function addon:HandleMacroRegenEnabled()
	if macroState.queued then
		macroState.queued = false
		self:EnsureMacro("combat ended")
	end
end

function addon:EnsureMacro(reason)
	if not macroIsEnabled() then
		return false, "Macro maintenance is disabled."
	end

	if type(CreateMacro) ~= "function" or type(EditMacro) ~= "function" then
		macroState.lastError = "Macro API is not available."
		return false, macroState.lastError
	end

	local candidates = self.GetCapturedTargets and self:GetCapturedTargets() or {}
	local body, truncated = renderWritableBody(candidates)
	macroState.truncated = truncated

	local existing, name, findError = findOwnedMacro()
	if findError then
		reportOnce(findError)
		return false, findError
	end

	if existing then
		if existing.body == body then
			storeMacroIndex(existing.index, name)
			macroState.lastError = nil
			return true, existing.index
		end

		local ok, result = pcall(EditMacro, existing.index, name, existing.icon or DEFAULT_ICON, body, true)
		if not ok then
			local message = ("Could not update macro %s: %s"):format(name, tostring(result))
			reportOnce(message)
			return false, message
		end

		storeMacroIndex(existing.index, name)
		macroState.lastError = nil
		if truncated then
			self:Print(("Macro %s was updated with the highest-priority targets that fit."):format(name))
		end
		return true, existing.index
	end

	local ok, result = pcall(CreateMacro, name, DEFAULT_ICON, body, true)
	if not ok or not result then
		local message = ("Could not create macro %s. Character macro slots may be full."):format(name)
		reportOnce(message)
		return false, message
	end

	storeMacroIndex(result, name)
	macroState.lastError = nil
	if truncated then
		self:Print(("Macro %s was created with the highest-priority targets that fit."):format(name))
	end
	return true, result
end
