ns = {}
NUM_BAG_SLOTS, NUM_CONTAINER_FRAMES = 4, 13
SlashCmdList, UISpecialFrames = {}, {}
local frames, timers = {}, {}
local methods = {}
for _, name in ipairs({ 'SetPoint', 'SetAllPoints', 'ClearAllPoints', 'SetSize', 'SetWidth', 'SetHeight',
	'SetFrameStrata', 'SetFrameLevel', 'SetClampedToScreen', 'SetMovable', 'EnableMouse', 'RegisterForDrag',
	'SetBackdrop', 'SetBackdropColor', 'SetBackdropBorderColor', 'SetJustifyH', 'SetTextColor', 'StartMoving',
	'StopMovingOrSizing', 'SetOwner', 'SetChecked', 'SetupMenu', 'SetTexCoord' }) do
	methods[name] = function() end
end
function methods:SetScript(name, callback) self.scripts[name] = callback end
function methods:HookScript(name, callback)
	local old = self.scripts[name]
	self.scripts[name] = function(...) if old then old(...) end; callback(...) end
end
function methods:RegisterEvent(name) self.events[name] = true end
function methods:GetName() return self.name end
function methods:GetObjectType() return self.kind end
function methods:GetParent() return self.parent end
function methods:GetID() return self.id or 0 end
function methods:GetFrameLevel() return 1 end
function methods:SetID(id) self.id = id end
function methods:IsShown() return self.shown ~= false end
function methods:IsVisible() return self:IsShown() and (not self.parent or self.parent:IsVisible()) end
function methods:Show()
	local was = self.shown
	self.shown = true
	if was == false and self.scripts.OnShow then self.scripts.OnShow(self) end
end
function methods:Hide()
	local was = self.shown
	self.shown = false
	if was ~= false and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:GetChildren() return unpack(self.children) end
function methods:SetTexture(texture) self.texture = texture end
function methods:SetPoint(...) self.point = {...} end
function methods:SetColorTexture(...) self.color = {...} end
function methods:SetText(text) self.text = text end
function methods:GetText() return self.text end
function methods:GetStringHeight()
	local _, count = (self.text or ''):gsub('\n', '')
	return (count + 1) * 14
end
function methods:GetOwner() return self.owner end
function methods:SetHyperlink(link) self.link = link end
local function Object(kind, name, parent)
	local frame = setmetatable({ kind = kind, name = name, parent = parent, children = {}, scripts = {}, events = {} }, {__index = methods})
	if name then _G[name] = frame end
	return frame
end
function methods:CreateTexture(name) return Object('Texture', name, self) end
function methods:CreateFontString(name) return Object('FontString', name, self) end
function CreateFrame(kind, name, parent)
	local frame = Object(kind, name, parent)
	frames[#frames + 1] = frame
	if parent then parent.children[#parent.children + 1] = frame end
	return frame
end
UIParent = CreateFrame('Frame', 'UIParent')
GameTooltip = CreateFrame('GameTooltip', 'GameTooltip', UIParent)
ItemRefTooltip = CreateFrame('GameTooltip', 'ItemRefTooltip', UIParent)
GameTooltip:Hide(); ItemRefTooltip:Hide()
C_Timer = {}
function C_Timer.After(delay, callback) timers[#timers + 1] = callback end
function C_Timer.NewTicker(delay, callback) return { callback = callback } end
function Flush(limit)
	for i = 1, limit or 20 do
		if #timers == 0 then return end
		local todo = timers; timers = {}
		for _, callback in ipairs(todo) do callback() end
	end
	assert(#timers == 0, 'Timers did not settle')
end
function Fire(event, ...)
	for _, frame in ipairs(frames) do
		if frame.events[event] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, event, ...) end
	end
end
function wipe(t) for key in pairs(t) do t[key] = nil end end
function hooksecurefunc(target, method, callback)
	local old = target[method]
	target[method] = function(...)
		local result = {old(...)}
		callback(...)
		return unpack(result)
	end
end
function GetTime() return 100 end
combat = false
function InCombatLockdown() return combat end
function UnitClass() return 'Warrior', 'WARRIOR' end
function UnitLevel() return 30 end
function CanDualWield() return true end
function SetItemButtonTexture(button, texture) button.Icon:SetTexture(texture) end
function SetItemButtonQuality() end
function GetInventoryItemLink(_, slot) return equipped[slot] end
function GetInventoryItemID(_, slot) return equipped[slot] and tonumber(equipped[slot]:match('item:(%d+)')) end
function GetQuestItemLink(kind, index) return rewards[kind .. index] end
function GetQuestLogItemLink(kind, index) return logRewards[kind .. index] end
function GetQuestItemInfo(kind, index)
	local link = rewards[kind .. index]
	local id = link and tonumber(link:match('item:(%d+)'))
	return id and items[id].name, 'icon', (rewardCounts and rewardCounts[kind .. index]) or 1, 2, true, id
end
function GetQuestLogChoiceInfo(index)
	local link = logRewards['choice' .. index]
	local id = link and tonumber(link:match('item:(%d+)'))
	return id and items[id].name, 'icon', 1, 2, true, id
end
function QuestInfo_ShowRewards() end
function QuestInfo_GetRewardButton(root, index) return root.RewardButtons[index] end
items, equipped, inventory, rewards, logRewards = {}, {}, { [0] = {} }, {}, {}
function AddItem(id, stats, loc, classID, subclassID, extra)
	local item = { id = id, name = 'Item ' .. id, stats = stats, loc = loc or 'INVTYPE_CHEST',
		classID = classID or 4, subclassID = subclassID or 2, level = 1 }
	for key, value in pairs(extra or {}) do item[key] = value end
	items[id] = item
	return 'item:' .. id
end
C_Item, C_TooltipInfo, C_Container = {}, {}, {}
function C_Item.GetItemInfo(link)
	local item = items[tonumber(link:match('item:(%d+)'))]
	if not item or item.loading then return end
	return item.name, link, 2, 20, item.level, '', '', 1, item.loc, 'icon' .. item.id, item.sell or 0, item.classID, item.subclassID
end
function C_Item.GetItemStats(link)
	local item = items[tonumber(link:match('item:(%d+)'))]
	if item.noStatsAPI then return nil end
	return item.stats
end
function C_Item.RequestLoadItemDataByID() end
function C_TooltipInfo.GetHyperlink(link)
	local item = items[tonumber(link:match('item:(%d+)'))]
	return { lines = item.lines or { {leftText = item.name}, {leftText = 'Chest', rightText = 'Leather'} } }
end
function C_Container.GetContainerNumSlots(bag) return inventory[bag] and 20 or 0 end
function C_Container.GetContainerItemLink(bag, slot)
	local link = inventory[bag] and inventory[bag][slot]
	return link and not missingLink and link or nil
end
function C_Container.GetContainerItemID(bag, slot)
	local link = inventory[bag] and inventory[bag][slot]
	return link and tonumber(link:match('item:(%d+)'))
end
function C_Container.GetContainerItemInfo(bag, slot)
	local link = inventory[bag] and inventory[bag][slot]
	if link then return {stackCount = 1, isLocked = locked} end
end
function CursorHasItem() return cursor ~= nil end
function C_Container.PickupContainerItem(bag, slot)
	assert(not combat, 'Protected pickup in combat')
	cursor = {bag = bag, slot = slot, link = inventory[bag][slot]}
end
function EquipCursorItem(slot)
	assert(not combat, 'Protected equip in combat')
	if needsBinding then bindingVisible = true; return end
	equipCalls = (equipCalls or 0) + 1
	lastEquipSlot = slot
	inventory[cursor.bag][cursor.slot], equipped[slot] = equipped[slot], cursor.link
	cursor = nil
end
function StaticPopup_Visible() return bindingVisible end
function ClearCursor() cursor = nil end
Settings = {
	RegisterCanvasLayoutCategory = function() return {GetID = function() return 1 end} end,
	RegisterAddOnCategory = function() end,
}
