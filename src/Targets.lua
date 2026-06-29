---@type string, NotAddon
local addonName, addon = ...

--- @class NotRaidmark
--- @field id number
--- @field label string

local raidMarks = {
	[1] = { id = 1, label = "Star" },
	[2] = { id = 2, label = "Circle" },
	[3] = { id = 3, label = "Diamond" },
	[4] = { id = 4, label = "Triangle" },
	[5] = { id = 5, label = "Moon" },
	[6] = { id = 6, label = "Square" },
	[7] = { id = 7, label = "Cross" },
	[8] = { id = 8, label = "Skull" },
}

addon.RAID_MARKS = raidMarks
addon.RAID_MARK_ORDER = { 8, 7, 6, 5, 4, 3, 2, 1 }

local capturedTargets = {}

local function trim(value)
	if type(value) ~= "string" then
		return nil
	end

	local trimmed = value:match("^%s*(.-)%s*$")
	if trimmed == "" then
		return nil
	end

	return trimmed
end

local function isValidMark(mark)
	return raidMarks[mark] ~= nil
end

local function normalizeEntry(entry)
	if type(entry) == "number" and isValidMark(entry) then
		return { type = "mark", mark = entry }
	end

	if type(entry) == "string" then
		local name = trim(entry)
		if name then
			return { type = "name", name = name }
		end
	end

	if type(entry) ~= "table" then
		return nil
	end

	if entry.type == "mark" then
		local mark = tonumber(entry.mark)
		if mark and isValidMark(mark) then
			return { type = "mark", mark = mark }
		end
	elseif entry.type == "name" then
		local name = trim(entry.name)
		if name then
			return { type = "name", name = name }
		end
	end

	return nil
end

local function sameEntry(left, right)
	if not left or not right or left.type ~= right.type then
		return false
	end

	if left.type == "mark" then
		return left.mark == right.mark
	end

	return left.name:lower() == right.name:lower()
end

local function removeMatching(priority, entry)
	for index = #priority, 1, -1 do
		if sameEntry(priority[index], entry) then
			table.remove(priority, index)
		end
	end
end

local function notifyOptionsChanged()
	if addon.NotifyOptionsChanged then
		addon:NotifyOptionsChanged()
	end
end

local function notifyTargetDataChanged(reason)
	if addon.RequestMacroRebuild then
		addon:RequestMacroRebuild(reason)
	end
end

local function normalizeName(value)
	value = trim(value)
	return value and value:lower() or nil
end

local function getNow()
	if type(GetTime) == "function" then
		return GetTime()
	end

	return 0
end

local function isInCombat()
	return type(InCombatLockdown) == "function" and InCombatLockdown()
end

local function getUnitName(unit)
	if type(UnitName) ~= "function" then
		return nil
	end

	local name, realm = UnitName(unit)
	name = trim(name)
	if not name then
		return nil
	end

	realm = trim(realm)
	if realm then
		return ("%s-%s"):format(name, realm)
	end

	return name
end

local function unitExists(unit)
	return type(UnitExists) == "function" and UnitExists(unit)
end

local function unitIsHostile(unit)
	return type(UnitCanAttack) == "function" and UnitCanAttack("player", unit)
end

local function unitIsDead(unit)
	return type(UnitIsDead) == "function" and UnitIsDead(unit)
end

local function getUnitGuid(unit)
	if type(UnitGUID) ~= "function" then
		return nil
	end

	return UnitGUID(unit)
end

local function getUnitMark(unit)
	if type(GetRaidTargetIndex) ~= "function" then
		return nil
	end

	return GetRaidTargetIndex(unit)
end

local function getCaptureKey(unit, name)
	return getUnitGuid(unit) or normalizeName(name)
end

local function priorityMatchesName(entry, name)
	local wanted = entry and normalizeName(entry.name)
	local actual = normalizeName(name)
	if not wanted or not actual then
		return false
	end

	return actual:sub(1, #wanted) == wanted
end

local function getPriorityMatch(name, mark)
	local profile = addon:GetProfile()
	local targets = profile and profile.targets
	if not targets then
		return nil
	end

	local priority = addon:GetPriorityList()
	for index = 1, #priority do
		local entry = priority[index]
		if entry.type == "mark" and mark and entry.mark == mark and targets.enabledMarks[mark] ~= false then
			return index, entry
		end

		if entry.type == "name" and priorityMatchesName(entry, name) then
			return index, entry
		end
	end

	return nil
end

local function candidateStillMatches(candidate)
	if not candidate then
		return false
	end

	local rank = getPriorityMatch(candidate.name, candidate.mark)
	if not rank then
		return false
	end

	candidate.priorityRank = rank
	return true
end

local function candidateSort(left, right)
	if left.priorityRank ~= right.priorityRank then
		return left.priorityRank < right.priorityRank
	end

	if left.lastSeen ~= right.lastSeen then
		return left.lastSeen > right.lastSeen
	end

	return left.name < right.name
end

function addon:GetRaidMarkLabel(mark)
	local metadata = raidMarks[mark]
	return metadata and metadata.label or ("Mark " .. tostring(mark))
end

function addon:GetRaidMarkOptionValues()
	local values = {}
	for index = 1, #self.RAID_MARK_ORDER do
		local mark = self.RAID_MARK_ORDER[index]
		values[mark] = ("%s ({rt%d})"):format(self:GetRaidMarkLabel(mark), mark)
	end
	return values
end

function addon:NormalizeTargetPriority()
	local profile = self:GetProfile()
	if not profile then
		return {}
	end

	profile.targets = profile.targets or {}
	local priority = profile.targets.priority
	if type(priority) ~= "table" then
		priority = {}
	end

	local normalized = {}
	for index = 1, #priority do
		local entry = normalizeEntry(priority[index])
		if entry then
			normalized[#normalized + 1] = entry
		end
	end

	profile.targets.priority = normalized
	return normalized
end

function addon:GetPriorityList()
	return self:NormalizeTargetPriority()
end

function addon:GetPriorityEntryLabel(entry)
	entry = normalizeEntry(entry)
	if not entry then
		return "Invalid priority"
	end

	if entry.type == "mark" then
		return "Raid mark: " .. self:GetRaidMarkLabel(entry.mark)
	end

	return "Name: " .. entry.name
end

function addon:GetPriorityOptionValues()
	local priority = self:GetPriorityList()
	local values = {}

	if #priority == 0 then
		values[0] = "No priority targets configured"
		return values
	end

	for index = 1, #priority do
		values[index] = ("%02d. %s"):format(index, self:GetPriorityEntryLabel(priority[index]))
	end

	return values
end

function addon:GetPriorityCount()
	return #self:GetPriorityList()
end

function addon:AddPriorityEntry(entry, addToTop)
	entry = normalizeEntry(entry)
	if not entry then
		return false, "Priority target is invalid."
	end

	local priority = self:GetPriorityList()
	removeMatching(priority, entry)

	local index = #priority + 1
	if addToTop then
		table.insert(priority, 1, entry)
		index = 1
	else
		priority[#priority + 1] = entry
	end

	notifyOptionsChanged()
	notifyTargetDataChanged("priority changed")
	return true, index, self:GetPriorityEntryLabel(entry)
end

function addon:AddPriorityMark(mark, addToTop)
	return self:AddPriorityEntry({ type = "mark", mark = tonumber(mark) }, addToTop)
end

function addon:AddPriorityName(name, addToTop)
	return self:AddPriorityEntry({ type = "name", name = trim(name) }, addToTop)
end

function addon:RemovePriorityEntry(index)
	local priority = self:GetPriorityList()
	index = tonumber(index)
	if not index or index < 1 or index > #priority then
		return false, "Select a priority target first."
	end

	table.remove(priority, index)
	notifyOptionsChanged()
	notifyTargetDataChanged("priority changed")
	return true
end

function addon:MovePriorityEntry(index, direction)
	local priority = self:GetPriorityList()
	index = tonumber(index)
	direction = tonumber(direction)
	if not index or not direction or index < 1 or index > #priority then
		return false, "Select a priority target first."
	end

	local targetIndex = index + direction
	if targetIndex < 1 or targetIndex > #priority then
		return false, "Priority target cannot move farther."
	end

	priority[index], priority[targetIndex] = priority[targetIndex], priority[index]
	notifyOptionsChanged()
	notifyTargetDataChanged("priority changed")
	return true, targetIndex
end

function addon:GetCurrentTargetName()
	if type(UnitExists) ~= "function" or not UnitExists("target") then
		return nil
	end

	if type(UnitName) ~= "function" then
		return nil
	end

	local name = UnitName("target")
	return trim(name)
end

function addon:AddCurrentTargetToPriority(addToTop)
	local name = self:GetCurrentTargetName()
	if not name then
		return false, "No target selected."
	end

	local ok, index, label = self:AddPriorityName(name, addToTop)
	if not ok then
		return ok, index
	end

	return true, index, label, name
end

function addon:InitializeTargets()
	self:RegisterEvent("UPDATE_MOUSEOVER_UNIT", "HandleMouseoverUnitUpdate")
end

function addon:HandleMouseoverUnitUpdate()
	self:HandleMouseoverUnit("mouseover")
end

function addon:HandleMouseoverUnit(unit)
	local profile = self:GetProfile()
	if not profile or not profile.targets or not profile.targets.captureEnabled then
		return false, "Target capture is disabled."
	end

	if isInCombat() then
		return false, "Target capture is skipped during combat."
	end

	if not unitExists(unit) or not unitIsHostile(unit) then
		return false, "Unit is not a hostile target."
	end

	local name = getUnitName(unit)
	if not name then
		return false, "Unit name is unavailable."
	end

	local key = getCaptureKey(unit, name)
	if not key then
		return false, "Unit key is unavailable."
	end

	if unitIsDead(unit) then
		if capturedTargets[key] then
			capturedTargets[key] = nil
			notifyTargetDataChanged("captured target died")
			return true
		end
		return false, "Unit is dead."
	end

	local mark = getUnitMark(unit)
	local rank = getPriorityMatch(name, mark)
	if not rank then
		return false, "Unit does not match configured target priorities."
	end

	capturedTargets[key] = {
		key = key,
		guid = getUnitGuid(unit),
		name = name,
		mark = mark,
		priorityRank = rank,
		lastSeen = getNow(),
	}

	notifyTargetDataChanged("captured mouseover target")
	return true
end

function addon:GetCapturedTargets()
	local candidates = {}

	for key, candidate in pairs(capturedTargets) do
		if candidateStillMatches(candidate) then
			candidates[#candidates + 1] = candidate
		else
			capturedTargets[key] = nil
		end
	end

	table.sort(candidates, candidateSort)
	return candidates
end

function addon:GetCapturedTargetCount()
	return #self:GetCapturedTargets()
end
