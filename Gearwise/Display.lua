local _, ns = ...
local Display = { buttons = setmetatable({}, { __mode = "k" }), arrows = setmetatable({}, { __mode = "k" }), hooks = {} }
ns.Display = Display
local MEDIA = "Interface\\AddOns\\Gearwise\\Media\\"
local labels = { str = "Strength", agi = "Agility", sta = "Stamina", int = "Intellect", spi = "Spirit",
	ap = "Attack power", rap = "Ranged AP", feralAP = "Feral AP", sp = "Spell power", heal = "Healing",
	armor = "Armor", bonusArmor = "Bonus armor", health = "Health", mana = "Mana", mp5 = "Mana / 5 sec",
	hp5 = "Health / 5 sec", dps = "Weapon DPS", crit = "Crit", hit = "Hit", dodge = "Dodge", parry = "Parry",
	block = "Block", defense = "Defense", blockValue = "Block value", critRating = "Crit rating",
	hitRating = "Hit rating", hasteRating = "Haste rating", expertiseRating = "Expertise", dodgeRating = "Dodge rating",
	parryRating = "Parry rating", blockRating = "Block rating", fire = "Fire damage", frost = "Frost damage",
	shadow = "Shadow damage", nature = "Nature damage", arcane = "Arcane damage", holy = "Holy damage" }
local percentStats = { crit = true, hit = true, dodge = true, parry = true, block = true }

function Display:Changes(result)
	local rows = {}
	for key, value in pairs(result.changes or {}) do
		local duplicateHealing = key == "heal" and math.abs(value - (result.changes.sp or 0)) < 0.01
		if math.abs(value) >= 0.01 and labels[key] and not duplicateHealing then
			local weight = ns.profile.weights[key] or 0
			if key == "dps" then weight = ns.profile.meleeDPS or ns.profile.rangedDPS or (ns.profile.wand and 5) or 0 end
			if key == ns.profile.school then weight = ns.profile.weights.sp or 0 end
			rows[#rows + 1] = { key = key, value = value, importance = math.abs(value * weight) }
		end
	end
	table.sort(rows, function(a, b)
		if a.importance == b.importance then return a.key < b.key end
		return a.importance > b.importance
	end)
	local lines, parts = {}, {}
	for index = 1, math.min(#rows, 6) do
		local row = rows[index]
		local format = math.abs(row.value - math.floor(row.value + 0.5)) < 0.01 and "%+d" or "%+.1f"
		local text = format:format(row.value) .. (percentStats[row.key] and "%" or "") .. " " .. labels[row.key]
		parts[#parts + 1] = (row.value > 0 and "|cff55df82" or "|cffff7777") .. text .. "|r"
		if #parts == 3 or index == math.min(#rows, 6) then
			lines[#lines + 1] = table.concat(parts, "   ")
			parts = {}
		end
	end
	if #rows > 6 then lines[#lines + 1] = ("+%d more stat changes"):format(#rows - 6) end
	return lines
end

local function TooltipLink(tooltip, data)
	if TooltipUtil and TooltipUtil.GetDisplayedItem then
		local _, link = TooltipUtil.GetDisplayedItem(tooltip)
		if ns.Text(link) then return link end
	end
	if data and ns.Text(data.hyperlink) then return data.hyperlink end
	if tooltip.GetItem then local _, link = tooltip:GetItem(); if ns.Text(link) then return link end end
end

function Display:Tooltip(tooltip, data)
	if not ns.db or not ns.db.tooltips or not ns.profile or self.inTooltip then return end
	if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
	local link = TooltipLink(tooltip, data)
	if not link or tooltip.gearwiseAdded then return end
	self.inTooltip = true
	local result = ns.Compare:Get(link)
	self.inTooltip = false
	if result.status == "irrelevant" then return end
	tooltip.gearwiseAdded = true
	tooltip.gearwiseLink = link
	tooltip.gearwiseRevision = ns.revision
	tooltip:AddLine(" ")
	local color, verdict = "|cffadb6c2", "Similar stats"
	local owner = tooltip.GetOwner and tooltip:GetOwner()
	local name = owner and owner.GetName and owner:GetName()
	if name and name:match("^Character.+Slot$") then
		verdict = "Equipped"
	elseif result.status == "upgrade" or result.status == "downgrade" then
		local up = result.status == "upgrade"
		color = up and "|cff55df82" or "|cffff7777"
		verdict = ("|T%s%s.tga:13:13|t %s"):format(MEDIA, up and "Upgrade" or "Downgrade", up and "Upgrade" or "Downgrade")
		if result.percent then verdict = verdict .. ("  %+.1f%% score"):format(result.percent)
		elseif result.empty then verdict = verdict .. "  Empty slot" end
	elseif result.status == "pending" then verdict = "Loading item data..."
	elseif result.status == "unusable" or result.status == "unsupported" then verdict = result.reason or "Cannot compare" end
	tooltip:AddDoubleLine("|cff8bc5e8Gearwise|r", color .. verdict .. "|r")
	tooltip:AddLine(ns.profile.label .. " " .. ns.profile.className .. (ns.profile.leveling and "  /  Leveling" or ""), 0.65, 0.69, 0.74)
	if verdict ~= "Equipped" then
		if result.oldLinks and #result.oldLinks > 0 then
			local slotLabel = result.slot == 17 and "Off hand" or (result.slot == 16 and "Main hand" or "Replaces")
			tooltip:AddLine(slotLabel .. ": " .. table.concat(result.oldLinks, " + "), 0.7, 0.73, 0.77, true)
		end
		for _, line in ipairs(self:Changes(result)) do tooltip:AddLine(line, 1, 1, 1, true) end
		if result.effects then tooltip:AddLine("Stat estimate; special effects and set bonuses need comparison.", 0.65, 0.69, 0.74, true) end
	end
end

local function BagLocation(button)
	if button.info and button.info.cached then return nil end
	local bag = button.GetBagID and button:GetBagID() or (button.GetBag and button:GetBag()) or button.bagID or button.bag
	if bag == nil and button.GetParent then
		local parent = button:GetParent()
		local name = parent and parent.GetName and parent:GetName()
		if name and name:match("^ContainerFrame%d+$") then bag = parent:GetID() end
	end
	if not ns.Number(bag) then return nil end
	if bag < 0 or bag > (NUM_BAG_SLOTS or 4) then return nil end
	if button.IsCached then
		local ok, cached = pcall(button.IsCached, button)
		if not ok or cached then return nil end
	end
	local slot = button.GetSlotID and button:GetSlotID() or (button.GetID and button:GetID())
	if not ns.Number(slot) or slot < 1 then return nil end
	return bag, slot
end

function Display:Track(button, kind)
	if not button or not button.CreateTexture then return end
	if kind == "quest" or button.type == "choice" or button.type == "reward" then
		self.buttons[button] = "quest"
	else
		local ok, bag = pcall(BagLocation, button)
		if ok and bag ~= nil then self.buttons[button] = "bag" end
	end
	self:Schedule()
end

function Display:Link(button, kind)
	if kind == "bag" then
		local bag, slot = BagLocation(button)
		if bag == nil then return nil end
		local getLink = C_Container and C_Container.GetContainerItemLink or GetContainerItemLink
		return getLink and getLink(bag, slot)
	end
	if button.objectType and button.objectType ~= "item" then return nil end
	if button.type ~= "choice" and button.type ~= "reward" then return nil end
	local index = button:GetID()
	if not ns.Number(index) or index <= 0 then return nil end
	local fromLog = QuestInfoFrame and QuestInfoFrame.questLog
	local getter = fromLog and GetQuestLogItemLink or GetQuestItemLink
	return getter and getter(button.type, index)
end

function Display:Arrow(button, result)
	local arrow = self.arrows[button]
	local direction = result and ((result.status == "upgrade" and "Upgrade") or (result.status == "downgrade" and "Downgrade"))
	if not direction then if arrow then arrow:Hide() end; return end
	if not arrow then
		if InCombatLockdown() then return end
		arrow = button:CreateTexture(nil, "OVERLAY", nil, 7)
		arrow:SetSize(16, 16)
		local icon = button.Icon or button.icon or button.IconTexture
		if not icon or not icon.GetObjectType then
			local name = button:GetName()
			icon = name and _G[name .. "IconTexture"] or button
		end
		arrow:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 1, 1)
		self.arrows[button] = arrow
	end
	arrow:SetTexture(MEDIA .. direction .. ".tga")
	arrow:Show()
end

function Display:Discover()
	local function Add(button) if button then self:Track(button, "quest") end end
	local function Root(root)
		if root and root:IsShown() and root.RewardButtons then
			for i = 1, #root.RewardButtons do Add(rawget(root.RewardButtons, i)) end
		end
	end
	Root(QuestInfoRewardsFrame)
	Root(MapQuestInfoRewardsFrame)
	for i = 1, 20 do
		for _, prefix in ipairs({ "QuestInfoItem", "QuestRewardItem", "QuestChoiceItem", "QuestLogItem" }) do
			local button = _G[prefix .. i]
			if button and button:IsShown() then Add(button) end
		end
	end
	for index = 1, (NUM_CONTAINER_FRAMES or 13) do
		local frame = _G["ContainerFrame" .. index]
		if frame and frame:IsShown() then
			local function AddBag(button)
				if not button then return end
				if not button.GetBagID and not button.GetBag and button.bagID == nil then
					-- Old Blizzard buttons expose their bag on the parent frame.
					self.buttons[button] = "bag"
				else self:Track(button) end
			end
			for _, button in pairs(frame.Items or {}) do AddBag(button) end
			for slot = 1, 40 do AddBag(_G["ContainerFrame" .. index .. "Item" .. slot]) end
		end
	end
	local combined = ContainerFrameCombinedBags
	if combined and combined:IsShown() then
		for _, button in pairs(combined.Items or {}) do self:Track(button) end
	end
end

function Display:Update()
	if not ns.profile then return end
	for button, kind in pairs(self.buttons) do
		if not button:IsVisible() or (kind == "bag" and not ns.db.bags) or (kind == "quest" and not ns.db.quests) then
			self:Arrow(button)
		else
			local ok, link = pcall(self.Link, self, button, kind)
			self:Arrow(button, ok and link and ns.Compare:Get(link) or nil)
		end
	end
	for _, tooltip in ipairs({ GameTooltip, ItemRefTooltip }) do
		if tooltip:IsShown() and tooltip.gearwiseLink and tooltip.gearwiseRevision ~= ns.revision
			and tooltip.RebuildFromTooltipInfo then
			pcall(tooltip.RebuildFromTooltipInfo, tooltip)
		end
	end
end

function Display:Schedule()
	if self.pending or not ns.loggedIn then return end
	self.pending = true
	C_Timer.After(0.1, function() self.pending = false; self:Update() end)
end

function Display:InstallHooks()
	local function Hook(target, method, callback)
		local key = tostring(target) .. ":" .. method
		if target and type(target[method]) == "function" and not self.hooks[key] then
			self.hooks[key] = true
			hooksecurefunc(target, method, callback)
		end
	end
	for _, method in ipairs({ "SetItemButtonQuality", "SetItemButtonTexture" }) do
		Hook(_G, method, function(button) self:Track(button) end)
	end
	for _, method in ipairs({ "Update", "UpdateItemContextMatching" }) do
		Hook(ContainerFrameItemButtonMixin, method, function(button) self:Track(button) end)
	end
	for _, method in ipairs({ "QuestInfo_ShowRewards", "QuestFrameItems_Update", "QuestLog_Update", "ContainerFrame_Update" }) do
		Hook(_G, method, function() self:Discover(); self:Schedule() end)
	end
	-- Bagnon's classes can be installed after its shared BagBrother addon.
	if Bagnon then
		Hook(Bagnon.Item or Bagnon.ItemSlot, "Update", function(button) self:Track(button) end)
	end
end

function Display:Init()
	for _, tooltip in ipairs({ GameTooltip, ItemRefTooltip }) do
		tooltip:HookScript("OnTooltipCleared", function(tip)
			tip.gearwiseAdded, tip.gearwiseLink, tip.gearwiseRevision = nil, nil, nil
		end)
	end
	if TooltipDataProcessor and Enum and Enum.TooltipDataType then
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tip, data) self:Tooltip(tip, data) end)
	else
		for _, tooltip in ipairs({ GameTooltip, ItemRefTooltip }) do
			tooltip:HookScript("OnTooltipSetItem", function(tip) self:Tooltip(tip) end)
		end
	end
	self:InstallHooks()
	self:Discover()
	C_Timer.NewTicker(0.5, function() self:Update() end)
end
