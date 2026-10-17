mock = { time = 1000, events = {}, timers = {}, items = {}, equipped = {}, bags = {},
	class = "MAGE", level = 25, talents = { 0, 0, 16 }, requests = {}, output = {} }
function wipe(t) for k in pairs(t) do t[k] = nil end end
function print(text) mock.output[#mock.output + 1] = text end
function GetTime() return mock.time end
function UnitClass() return mock.class:sub(1, 1) .. mock.class:sub(2):lower(), mock.class end
function UnitLevel() return mock.level end
function InCombatLockdown() return mock.combat or false end
function issecretvalue(v) return type(v) == "table" and v.secret == true end
function canaccessvalue(v) return not issecretvalue(v) end
function GetNumTalents() return 30 end
function GetTalentInfo(tab, index)
	local rank = math.max(0, math.min(5, (mock.talents[tab] or 0) - ((index or 1) - 1) * 5))
	return "Talent", 12345, 1, 1, rank
end
function GetInventoryItemLink(_, slot) return mock.equipped[slot] end
function GetInventoryItemID(_, slot)
	local link = mock.equipped[slot]
	return link and tonumber(link:match("item:(%d+)")) or (mock.uncachedSlots and mock.uncachedSlots[slot])
end
function CanDualWield() return mock.dualWield or false end
function GetQuestItemLink(kind, id) return mock.quest and mock.quest[kind .. id] end
function GetQuestLogItemLink(kind, id) return mock.questLog and mock.questLog[kind .. id] end
SlashCmdList = {}
NUM_BAG_SLOTS = 4

C_Timer = {}
function C_Timer.After(delay, fn) mock.timers[#mock.timers + 1] = { at = mock.time + delay, fn = fn } end
function C_Timer.NewTicker(delay, fn) mock.timers[#mock.timers + 1] = { at = mock.time + delay, fn = fn, interval = delay } end
function mock.Advance(seconds)
	mock.time = mock.time + seconds
	local due = {}
	for i = #mock.timers, 1, -1 do
		local timer = mock.timers[i]
		if timer.at <= mock.time then
			due[#due + 1] = timer
			if timer.interval then timer.at = mock.time + timer.interval else table.remove(mock.timers, i) end
		end
	end
	for _, timer in ipairs(due) do timer.fn() end
end

local Region = {}
Region.__index = Region
function CreateFrame(kind, name, parent, template)
	local frame = setmetatable({ kind = kind, name = name, parent = parent, template = template,
		scripts = {}, shown = true, lines = {}, points = {} }, Region)
	if name then _G[name] = frame end
	return frame
end
function Region:RegisterEvent(event) mock.events[event] = mock.events[event] or {}; table.insert(mock.events[event], self) end
function Region:SetScript(name, fn) self.scripts[name] = fn end
function Region:HookScript(name, fn)
	local old = self.scripts[name]
	self.scripts[name] = function(...) if old then old(...) end; fn(...) end
end
function Region:GetName() return self.name end
function Region:GetParent() return self.parent end
function Region:GetOwner() return self.owner end
function Region:GetID() return self.id or 0 end
function Region:SetID(id) self.id = id end
function Region:SetSize(w, h) self.w, self.h = w, h end
function Region:SetAllPoints(frame) self.allPoints = frame end
function Region:GetFrameLevel() return self.frameLevel or 1 end
function Region:SetFrameLevel(level) self.frameLevel = level end
function Region:ClearAllPoints() self.points = {} end
function Region:SetColorTexture(...) self.color = { ... } end
function Region:SetFrameStrata(strata) self.strata = strata end
function Region:SetClampedToScreen() end
function Region:SetMovable() end
function Region:EnableMouse() end
function Region:RegisterForDrag() end
function Region:StartMoving() end
function Region:StopMovingOrSizing() end
function Region:SetBackdrop() end
function Region:SetBackdropColor() end
function Region:SetBackdropBorderColor() end
function Region:SetWidth(w) self.w = w end
function Region:SetPoint(...) self.points[#self.points + 1] = { ... } end
function Region:SetText(text) self.text = text end
function Region:GetText() return self.text end
function Region:SetTextColor(...) self.color = { ... } end
function Region:SetJustifyH() end
function Region:SetChecked(value) self.checked = value end
function Region:GetChecked() return self.checked end
function Region:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
function Region:Hide() self.shown = false end
function Region:IsShown() return self.shown end
function Region:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function Region:CreateFontString() return CreateFrame("FontString", nil, self) end
function Region:CreateTexture() return CreateFrame("Texture", nil, self) end
function Region:GetObjectType() return self.kind end
function Region:SetTexture(path) self.texture = path end
function Region:SetupMenu(fn)
	local root = { options = {} }
	function root:CreateRadio(label, selected, callback) self.options[#self.options + 1] = { label, selected, callback } end
	fn(self, root)
	self.menu = root
end
function Region:AddLine(text) self.lines[#self.lines + 1] = text end
function Region:AddDoubleLine(left, right) self.lines[#self.lines + 1] = left .. " | " .. right end
function Region:GetItem() return nil, self.item end
function Region:ClearLines()
	self.lines = {}
	if self.scripts.OnTooltipCleared then self.scripts.OnTooltipCleared(self) end
end
function Region:RebuildFromTooltipInfo()
	local link = self.item
	self:ClearLines()
	mock.tooltipCallback(self, { hyperlink = link })
end
function mock.Fire(event, ...)
	for _, frame in ipairs(mock.events[event] or {}) do
		if frame.scripts.OnEvent then frame.scripts.OnEvent(frame, event, ...) end
	end
end
function hooksecurefunc(target, key, hook)
	local old = target[key]
	assert(type(old) == "function", "hook target absent")
	target[key] = function(...)
		local result = { old(...) }
		hook(...)
		return unpack(result)
	end
end
UIParent = CreateFrame("Frame", "UIParent")
GameTooltip = CreateFrame("GameTooltip", "GameTooltip")
ItemRefTooltip = CreateFrame("GameTooltip", "ItemRefTooltip")
Settings = {}
function Settings.RegisterCanvasLayoutCategory(panel) return { GetID = function() return 101 end } end
function Settings.RegisterAddOnCategory() end
function Settings.OpenToCategory(id) mock.openCategory = id end
Enum = { TooltipDataType = { Item = 1 } }
TooltipDataProcessor = {}
function TooltipDataProcessor.AddTooltipPostCall(_, fn) mock.tooltipCallback = fn end
function mock.ShowTooltip(link, tooltip)
	tooltip = tooltip or GameTooltip
	tooltip:ClearLines()
	tooltip.item = link
	mock.tooltipCallback(tooltip, { hyperlink = link })
	return table.concat(tooltip.lines, "\n")
end
function SetItemButtonQuality() end
function SetItemButtonTexture() end
function QuestInfo_ShowRewards() end
function ContainerFrame_Update() end
ContainerFrameItemButtonMixin = { Update = function() end }
C_Container = {}
function C_Container.GetContainerNumSlots(bag) return #(mock.bags[bag] or {}) end
function C_Container.GetContainerItemLink(bag, slot) return mock.bags[bag] and mock.bags[bag][slot] end
C_Item = {}
function C_Item.GetItemInfo(link)
	local item = mock.items[link]
	if not item or item.uncached then return end
	return item.name or link, link, 2, 20, item.level or 1, "Armor", "Cloth", 1,
		item.loc or "INVTYPE_CHEST", 123, 10, item.classID or 4, item.subclassID or 1, 1, 0, item.setID
end
function C_Item.GetItemStats(link)
	local item = mock.items[link]
	if item and not item.missingStats then return item.stats or {} end
end
function C_Item.RequestLoadItemDataByID(id) mock.requests[id] = (mock.requests[id] or 0) + 1 end
function C_Item.GetItemUniqueness(link)
	local item = mock.items[link]
	return item.limit or 0, item.limitMax or 0
end
C_TooltipInfo = {}
function C_TooltipInfo.GetHyperlink(link)
	local item = mock.items[link]
	if not item or item.missingTooltip then return nil end
	local lines = {}
	for _, text in ipairs(item.lines or { item.name or link }) do
		lines[#lines + 1] = type(text) == "string" and { leftText = text } or text
	end
	return { lines = lines }
end
