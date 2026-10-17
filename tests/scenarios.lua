local passed = 0
local function Test(name, test)
	test()
	passed = passed + 1
	print('PASS ' .. name)
end
local old = AddItem(100, {ITEM_MOD_STRENGTH_SHORT = 2, RESISTANCE0_NAME = 50})
local upgrade = AddItem(101, {ITEM_MOD_STRENGTH_SHORT = 5, RESISTANCE0_NAME = 60})
local downgrade = AddItem(102, {ITEM_MOD_STRENGTH_SHORT = 1, RESISTANCE0_NAME = 40})
local plate = AddItem(103, {}, 'INVTYPE_CHEST', 4, 4)
equipped[5], inventory[0][1] = old, downgrade
Fire('ADDON_LOADED', 'Gearwise')
Fire('PLAYER_LOGIN')
Flush()

Test('login initializes without prompting for existing items', function()
	assert(ns.db.popups and ns.db.unusable)
	assert(not ns.Upgrades.current)
end)

Test('comparison reports upgrade, downgrade, and item stat deltas', function()
	local result = ns.Compare:Get(upgrade)
	assert(result.status == 'upgrade', ns.Compare.lastError or ns.Items.lastError)
	assert(result.slot == 5 and result.changes.str == 3 and result.changes.armor == 10)
	assert(ns.Compare:Get(downgrade).status == 'downgrade')
	assert(ns.Compare:Get(plate).status == 'unusable')
end)

local bagFrame = CreateFrame('Frame', 'BagnonInventory', UIParent)
local bagButton = CreateFrame('Button', 'BagnonItem99', bagFrame)
bagButton.bag = 0; bagButton:SetID(1)
bagButton.Icon = bagButton:CreateTexture()
Bagnon = { Frames = { Get = function() return bagFrame end } }

Test('discovers pre-existing Bagnon buttons and renders top-right downgrade arrow', function()
	ns.Display:Update()
	assert(ns.Display.buttons[bagButton] == 'bag')
	assert(ns.Display.arrows[bagButton]:IsShown())
	assert(ns.Display.arrows[bagButton].texture:find('Downgrade.tga', 1, true))
	assert(ns.Display.arrows[bagButton].point[1] == 'TOPRIGHT' and ns.Display.arrows[bagButton].point[2] == bagButton.Icon)
end)

Test('red shade appears for unusable items and clears when slot changes', function()
	inventory[0][1] = plate; ns.Display:Update()
	assert(ns.Display.shades[bagButton]:IsShown())
	assert(not ns.Display.arrows[bagButton]:IsShown())
	inventory[0][1] = downgrade; ns.Display:Update()
	assert(not ns.Display.shades[bagButton]:IsShown())
	assert(ns.Display.arrows[bagButton]:IsShown())
end)

Test('arrow and shade options operate independently', function()
	ns.db.bags = false; inventory[0][1] = plate; ns.Display:Update()
	assert(ns.Display.shades[bagButton]:IsShown())
	ns.db.unusable = false; ns.Display:Update()
	assert(not ns.Display.shades[bagButton]:IsShown())
	ns.db.bags, ns.db.unusable, inventory[0][1] = true, true, downgrade
end)

QuestInfoFrame = { questLog = false }
QuestInfoRewardsFrame = CreateFrame('Frame', 'QuestInfoRewardsFrame', UIParent)
local reward = CreateFrame('Button', 'PooledQuestReward77', QuestInfoRewardsFrame)
reward.Icon = reward:CreateTexture()
reward.type, reward.objectType = 'choice', 'item'; reward:SetID(1)
QuestInfoRewardsFrame.RewardButtons = {reward}
rewards.choice1, logRewards.choice1 = upgrade, downgrade

Test('pooled quest reward and quest log rewards use their correct links', function()
	ns.Display:Update()
	assert(ns.Display.arrows[reward].texture:find('Upgrade.tga', 1, true))
	-- The global quest-log flag must not redirect an NPC reward to the log's item.
	QuestInfoFrame.questLog = true; ns.Display:Update()
	assert(ns.Display.arrows[reward].texture:find('Upgrade.tga', 1, true))
	MapQuestInfoRewardsFrame = CreateFrame('Frame', 'MapQuestInfoRewardsFrame', UIParent)
	local preview = CreateFrame('Button', nil, MapQuestInfoRewardsFrame)
	preview.Icon = preview:CreateTexture(); preview.type = 'choice'; preview:SetID(1)
	MapQuestInfoRewardsFrame.RewardButtons = {preview}
	ns.Display:Update()
	assert(ns.Display.arrows[preview].texture:find('Downgrade.tga', 1, true))
	MapQuestInfoRewardsFrame:Hide()
	QuestInfoFrame.questLog = false
	rewards.choice1 = downgrade; ns.Display:Update()
	assert(ns.Display.arrows[reward].texture:find('Downgrade.tga', 1, true))
	rewards.choice1 = plate; ns.Display:Update()
	assert(ns.Display.shades[reward]:IsShown())
	reward.objectType = 'currency'; ns.Display:Update()
	assert(not ns.Display.shades[reward]:IsShown() and not ns.Display.arrows[reward]:IsShown())
	reward.objectType = 'item'
end)

Test('right-side red weapon proficiency is treated as unusable and invalidated on learning', function()
	local weapon = AddItem(104, {}, 'INVTYPE_WEAPON', 2, 7, {lines = {
		{leftText = 'Item 104'}, {leftText = 'One-Hand', rightText = 'Swords', rightColor = {r = 1, g = 0.1}}}})
	assert(ns.Compare:Get(weapon).status == 'unusable')
	items[104].lines[2].rightColor = {r = 1, g = 1}
	Fire('SPELLS_CHANGED'); Flush()
	assert(ns.Compare:Get(weapon).status ~= 'unusable')
end)

Test('shield build does not mark wearable two-handed weapons red', function()
	local twohand = AddItem(110, {ITEM_MOD_STRENGTH_SHORT = 8, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 20}, 'INVTYPE_2HWEAPON', 2, 8)
	ns.profile.shield = true; ns.Compare:Clear()
	assert(ns.Compare:Get(twohand).status == 'unsupported')
	ns.profile.shield = nil; ns.Compare:Clear()
	equipped[16] = AddItem(111, {ITEM_MOD_STRENGTH_SHORT = 3, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 8}, 'INVTYPE_WEAPON', 2, 7)
	equipped[17] = AddItem(112, {ITEM_MOD_STRENGTH_SHORT = 1, RESISTANCE0_NAME = 120}, 'INVTYPE_SHIELD', 4, 6)
	local result = ns.Compare:Get(twohand)
	assert(result.status == 'upgrade' and #result.oldLinks == 2)
	assert(result.oldLinks[1] == equipped[16] and result.oldLinks[2] == equipped[17])
	assert(result.changes.str == 4 and result.changes.armor == -120 and result.changes.dps == 12)
end)

Test('new acquisition opens comparison without equipping', function()
	-- Reset baseline after test fixtures changed the inventory.
	ns.Upgrades:Scan(); Flush()
	inventory[0][2] = upgrade; Fire('BAG_UPDATE_DELAYED'); Flush()
	assert(ns.Upgrades.current and ns.Upgrades.current.link == upgrade)
	assert(ns.Upgrades.frame:IsShown() and (equipCalls or 0) == 0)
	assert(ns.Upgrades.frame.old[1].link == old and ns.Upgrades.frame.new.link == upgrade)
	assert(ns.Upgrades.frame.changes:GetText():find('+3 Strength', 1, true))
end)

Test('combat hides prompt and resumes afterward', function()
	combat = true; Fire('PLAYER_REGEN_DISABLED')
	assert(not ns.Upgrades.frame:IsShown())
	ns.Upgrades:Equip(); assert((equipCalls or 0) == 0)
	combat = false; Fire('PLAYER_REGEN_ENABLED'); Flush()
	assert(ns.Upgrades.frame:IsShown())
end)

Test('sorting relocates the candidate without generating a second popup', function()
	inventory[0][9], inventory[0][2] = inventory[0][2], nil
	Fire('BAG_UPDATE_DELAYED'); Flush()
	assert(ns.Upgrades.current.slot == 9 and #ns.Upgrades.queue == 0)
end)

Test('locked item and cursor item block equip without losing prompt', function()
	locked = true; ns.Upgrades:Equip(); assert((equipCalls or 0) == 0)
	locked = false; cursor = {}; ns.Upgrades:Equip(); assert((equipCalls or 0) == 0)
	cursor = nil
end)

Test('click equip uses the reviewed inventory slot and avoids displaced-item popup', function()
	ns.Upgrades:Equip()
	assert(equipCalls == 1 and lastEquipSlot == 5 and equipped[5] == upgrade)
	Fire('PLAYER_EQUIPMENT_CHANGED'); Flush()
	assert(not ns.Upgrades.current and #ns.Upgrades.queue == 0)
end)

Test('pending item cache is retried instead of dropping the acquisition', function()
	local delayed = AddItem(120, {ITEM_MOD_STRENGTH_SHORT = 12}, nil, nil, nil, {loading = true})
	inventory[0][3] = delayed
	ns.Upgrades:Scan()
	assert(not ns.Upgrades.current and #ns.Upgrades.queue == 1)
	items[120].loading = false; Fire('GET_ITEM_INFO_RECEIVED'); Flush()
	assert(ns.Upgrades.current.link == delayed)
	ns.Upgrades:Dismiss()
	Fire('BAG_UPDATE_DELAYED'); Flush()
	assert(not ns.Upgrades.current)
end)

Test('changed equipped item requires review before equip', function()
	ns.Upgrades:Scan(true)
	assert(ns.Upgrades.current)
	equipped[5] = old -- change without firing an event before the click
	local calls = equipCalls
	ns.Upgrades:Equip()
	assert(equipCalls == calls and ns.Upgrades.result.oldLinks[1] == old)
	ns.Upgrades:Dismiss(); Flush()
end)

Test('disabling popups clears current and queued upgrades', function()
	ns.Upgrades:Scan(true)
	ns:SetOption('popups', false); Flush()
	assert(not ns.Upgrades.current and #ns.Upgrades.queue == 0 and not ns.Upgrades.frame:IsShown())
	ns:SetOption('popups', true); Flush()
	assert(not ns.Upgrades.current)
end)

Test('missing item links do not corrupt inventory baseline', function()
	local before = ns.Upgrades.counts
	missingLink = true; ns.Upgrades:Scan()
	assert(ns.Upgrades.counts == before)
	missingLink = false; Flush()
	assert(not ns.Upgrades.current)
end)

Test('tooltip parsing handles items with no GetItemStats result', function()
	local noStats = AddItem(130, {}, nil, nil, nil, {noStatsAPI = true,
		lines = {{leftText = 'Item 130'}, {leftText = '+4 Strength'}}})
	local item = ns.Items:Get(noStats)
	assert(item and item.stats.str == 4, ns.Items.lastError)
end)

Test('popup includes every stat change rather than the tooltip summary limit', function()
	local changes = {str = 1, agi = 2, sta = 3, int = 4, spi = 5, armor = -6, health = 7, mana = 8, fireResist = 9}
	local lines = ns.Display:Changes({changes = changes}, math.huge, 2)
	assert(#lines == 5 and not table.concat(lines):find('more stat changes', 1, true))
end)

Test('two-handed popup displays both currently equipped items', function()
	inventory[0][4] = 'item:110'; ns.Upgrades:Scan(); Flush()
	assert(ns.Upgrades.current.link == 'item:110')
	assert(ns.Upgrades.frame.old[1].link == equipped[16])
	assert(ns.Upgrades.frame.old[2].link == equipped[17] and ns.Upgrades.frame.old[2]:IsShown())
	assert(ns.Upgrades.frame.note:GetText():find('Replaces main hand and off hand.', 1, true))
	ns.Upgrades:Dismiss(); Flush()
end)

Test('ring upgrade targets the weaker ring and respects unique-equipped restrictions', function()
	equipped[11] = AddItem(140, {ITEM_MOD_STRENGTH_SHORT = 10}, 'INVTYPE_FINGER', 4, 0)
	equipped[12] = AddItem(141, {ITEM_MOD_STRENGTH_SHORT = 2}, 'INVTYPE_FINGER', 4, 0)
	local ring = AddItem(142, {ITEM_MOD_STRENGTH_SHORT = 5}, 'INVTYPE_FINGER', 4, 0)
	Fire('PLAYER_EQUIPMENT_CHANGED'); Flush()
	local result = ns.Compare:Get(ring)
	assert(result.status == 'upgrade' and result.slot == 12 and result.changes.str == 3)
	items[142].lines = {{leftText = 'Item 142'}, {leftText = 'Unique-Equipped'}}
	equipped[11] = ring
	Fire('PLAYER_EQUIPMENT_CHANGED'); Flush()
	result = ns.Compare:Get(ring)
	assert(result.status == 'equal' and result.slot == 11)
	equipped[11], equipped[12] = nil, nil
	Fire('PLAYER_EQUIPMENT_CHANGED'); Flush()
end)

Test('trinket upgrade equips exactly the weaker slot', function()
	equipped[13] = AddItem(150, {ITEM_MOD_STRENGTH_SHORT = 12}, 'INVTYPE_TRINKET', 4, 0)
	equipped[14] = AddItem(151, {ITEM_MOD_STRENGTH_SHORT = 1}, 'INVTYPE_TRINKET', 4, 0)
	local trinket = AddItem(152, {ITEM_MOD_STRENGTH_SHORT = 6}, 'INVTYPE_TRINKET', 4, 0)
	Fire('PLAYER_EQUIPMENT_CHANGED'); Flush()
	inventory[0][5] = trinket; Fire('BAG_UPDATE_DELAYED'); Flush()
	assert(ns.Upgrades.current.link == trinket and ns.Upgrades.result.slot == 14)
	ns.Upgrades:Equip(); Fire('PLAYER_EQUIPMENT_CHANGED'); Flush()
	assert(lastEquipSlot == 14 and equipped[14] == trinket and equipped[13] == 'item:150')
end)

Test('binding confirmation keeps cursor and comparison until player confirms', function()
	local bind = AddItem(160, {ITEM_MOD_STRENGTH_SHORT = 20})
	inventory[0][6] = bind; Fire('BAG_UPDATE_DELAYED'); Flush()
	assert(ns.Upgrades.current.link == bind)
	local calls = equipCalls
	needsBinding = true; ns.Upgrades:Equip(); Flush()
	assert(bindingVisible and cursor and equipCalls == calls and ns.Upgrades.frame:IsShown())
	needsBinding = false; bindingVisible = false
	EquipCursorItem(ns.Upgrades.result.slot)
	Fire('PLAYER_EQUIPMENT_CHANGED'); Flush()
	assert(not ns.Upgrades.current and equipped[5] == bind)
end)

Test('new upgrade acquired during combat waits until combat ends', function()
	local combatItem = AddItem(170, {ITEM_MOD_STRENGTH_SHORT = 30})
	combat = true; Fire('PLAYER_REGEN_DISABLED')
	inventory[0][7] = combatItem; Fire('BAG_UPDATE_DELAYED'); Flush()
	assert(not ns.Upgrades.frame:IsShown() and #ns.Upgrades.queue > 0)
	combat = false; Fire('PLAYER_REGEN_ENABLED'); Flush()
	assert(ns.Upgrades.current.link == combatItem and ns.Upgrades.frame:IsShown())
	ns.Upgrades:Dismiss(); Flush()
end)

Test('native bag iterators and combined bag buttons are discovered', function()
	ContainerFrame1 = CreateFrame('Frame', 'ContainerFrame1', UIParent)
	ContainerFrame1:SetID(0)
	local native = CreateFrame('Button', nil, ContainerFrame1)
	native:SetID(7); native.Icon = native:CreateTexture()
	function native:GetBagID() return 0 end
	function ContainerFrame1:EnumerateValidItems() return ipairs({native}) end
	ContainerFrameCombinedBags = CreateFrame('Frame', 'ContainerFrameCombinedBags', UIParent)
	local combined = CreateFrame('Button', nil, ContainerFrameCombinedBags)
	combined.bagID = 0; combined:SetID(7); combined.Icon = combined:CreateTexture()
	ContainerFrameCombinedBags.Items = {combined}
	ns.Display:Update()
	assert(ns.Display.buttons[native] == 'bag' and ns.Display.buttons[combined] == 'bag')
	assert(ns.Display.arrows[native]:IsShown() and ns.Display.arrows[combined]:IsShown())
end)

Test('NPC reward arrows use item IDs when hyperlinks are not ready', function()
	local questUpgrade = AddItem(200, {ITEM_MOD_STRENGTH_SHORT = 40}, nil, nil, nil, {sell = 1000})
	rewards.choice1 = questUpgrade
	local getter = GetQuestItemLink
	GetQuestItemLink = function() return nil end
	QuestInfoFrame.questLog = true
	ns.Display:Update()
	assert(ns.Display:Link(reward, 'quest') == questUpgrade)
	assert(ns.Display.arrows[reward]:IsShown() and ns.Display.arrows[reward].texture:find('Upgrade.tga', 1, true))
	assert(ns.Display.arrows[reward]:GetParent():GetParent() == reward)
	GetQuestItemLink = getter
	QuestInfoFrame.questLog = false
end)

Test('actual named reward buttons are discovered without a RewardButtons array', function()
	local array = QuestInfoRewardsFrame.RewardButtons
	QuestInfoRewardsFrame.RewardButtons = nil
	local named = CreateFrame('Button', 'QuestInfoRewardsFrameQuestInfoItem8', QuestInfoRewardsFrame)
	named.Icon = named:CreateTexture(); named.type = 'choice'; named:SetID(8)
	rewards.choice8 = 'item:200'
	ns.Display:Update()
	assert(ns.Display.buttons[named] == 'quest' and ns.Display.arrows[named]:IsShown())
	named:Hide(); QuestInfoRewardsFrame.RewardButtons = array
end)

local second = CreateFrame('Button', nil, QuestInfoRewardsFrame)
second.Icon = second:CreateTexture(); second.type = 'choice'; second:SetID(2)
local fixed = CreateFrame('Button', nil, QuestInfoRewardsFrame)
fixed.Icon = fixed:CreateTexture(); fixed.type = 'reward'; fixed:SetID(1)
QuestInfoRewardsFrame.RewardButtons = {reward, second, fixed}
local cheap = AddItem(210, {ITEM_MOD_STRENGTH_SHORT = 1}, nil, nil, nil, {sell = 12000})
local stacked = AddItem(211, {}, 'INVTYPE_CHEST', 4, 4, {sell = 5000})
local guaranteed = AddItem(212, {ITEM_MOD_STRENGTH_SHORT = 50}, nil, nil, nil, {sell = 99999})
rewardCounts = {choice2 = 3}
rewards.choice1, rewards.choice2, rewards.reward1 = cheap, stacked, guaranteed

Test('no-upgrade quest choices mark the highest total vendor value, ignoring fixed rewards', function()
	ns.Display:Update()
	assert(ns.Display.coins[second]:IsShown())
	assert(not ns.Display.coins[reward] or not ns.Display.coins[reward]:IsShown())
	assert(not ns.Display.coins[fixed] or not ns.Display.coins[fixed]:IsShown())
	assert(ns.Display.shades[second]:IsShown())
	assert(ns.Display.arrows[reward]:IsShown())
	rewardCounts.choice2 = 1; ns.Display:Update()
	assert(ns.Display.coins[reward]:IsShown() and not ns.Display.coins[second]:IsShown())
end)

Test('upgrade arrow and best-value coin appear together on different reward choices', function()
	rewards.choice1 = 'item:200'; ns.Display:Update()
	assert(not ns.Display.coins[reward]:IsShown() and ns.Display.coins[second]:IsShown())
	assert(ns.Display.arrows[reward].texture:find('Upgrade.tga', 1, true))
	rewards.choice1 = cheap
end)

Test('vendor recommendation waits for every reward to load', function()
	local pending = AddItem(213, {}, 'INVTYPE_CHEST', 4, 4, {sell = 50000, loading = true})
	rewards.choice2 = pending; ns.Display:Update()
	assert(not ns.Display.coins[reward]:IsShown() and not ns.Display.coins[second]:IsShown())
	items[213].loading = false; Fire('QUEST_ITEM_UPDATE'); Flush()
	assert(ns.Display.coins[second]:IsShown())
end)

Test('coin ties choose the first reward and markers clear on settings, hide, and zero value', function()
	rewards.choice2 = stacked; items[211].sell = items[210].sell
	ns.Display:Update()
	assert(ns.Display.coins[reward]:IsShown() and not ns.Display.coins[second]:IsShown())
	ns.db.quests = false; ns.Display:Update()
	assert(not ns.Display.coins[reward]:IsShown())
	ns.db.quests = true; ns.Display:Update(); reward:Hide()
	assert(not ns.Display.coins[reward]:IsShown())
	reward:Show(); items[210].sell, items[211].sell = 0, 0
	ns.Display:Update()
	assert(not ns.Display.coins[reward]:IsShown() and not ns.Display.coins[second]:IsShown())
end)

local cloth8 = AddItem(350, {RESISTANCE0_NAME = 8}, 'INVTYPE_CHEST', 4, 1)
local cloth10 = AddItem(351, {RESISTANCE0_NAME = 10}, 'INVTYPE_CHEST', 4, 1)

Test('8-to-10 cloth armor is an upgrade for every build and the reverse is a downgrade', function()
	local savedProfile, savedChest = ns.profile, equipped[5]
	for class, builds in pairs(ns.Profiles.classes) do
		for _, build in ipairs(builds) do
			ns.profile = {class = class, level = 30, label = build.label, className = class, weights = build.weights}
			equipped[5] = cloth8; ns.Compare:Clear()
			local result = ns.Compare:Get(cloth10)
			assert(result.status == 'upgrade' and result.changes.armor == 2, class .. ' ' .. build.key)
			equipped[5] = cloth10; ns.Compare:Clear()
			assert(ns.Compare:Get(cloth8).status == 'downgrade', class .. ' ' .. build.key)
		end
	end
	ns.profile, equipped[5] = savedProfile, savedChest; ns.Compare:Clear()
end)

Test('small armor gains remain visible alongside large existing stat scores', function()
	local savedChest = equipped[5]
	local before = AddItem(353, {RESISTANCE0_NAME = 8, ITEM_MOD_STRENGTH_SHORT = 100}, 'INVTYPE_CHEST', 4, 1)
	local after = AddItem(354, {RESISTANCE0_NAME = 10, ITEM_MOD_STRENGTH_SHORT = 100}, 'INVTYPE_CHEST', 4, 1)
	equipped[5] = before; ns.Compare:Clear()
	local result = ns.Compare:Get(after)
	assert(result.status == 'upgrade' and result.changes.armor == 2 and result.changes.str == 0)
	assert(ns.Compare:Get(before).status == 'equal')
	equipped[5] = savedChest; ns.Compare:Clear()
end)

-- Exercise the exact reported case through the slash command and visible UI.
UnitClass = function() return 'Mage', 'MAGE' end
UnitLevel = function() return 10 end
inventory = {[0] = {[1] = cloth10}}
equipped[5] = cloth8
ns.Upgrades.current = nil; wipe(ns.Upgrades.queue); wipe(ns.Upgrades.queued)
local messages = {}
ns.Print = function(message) messages[#messages + 1] = message end

Test('/gw upgrades opens the +2 armor popup and both bag and quest arrows show up', function()
	SlashCmdList.GEARWISE('upgrades'); Flush()
	assert(ns.Upgrades.current.link == cloth10 and ns.Upgrades.result.changes.armor == 2)
	assert(ns.Upgrades.frame:IsShown() and ns.Upgrades.frame.changes:GetText():find('+2 Armor', 1, true))
	assert(table.concat(messages, '\n'):find('Found 1 bag upgrade', 1, true))
	rewards.choice1 = cloth10; ns.Display:Update()
	assert(ns.Display.arrows[bagButton]:IsShown() and ns.Display.arrows[bagButton].texture:find('Upgrade.tga', 1, true))
	assert(ns.Display.arrows[reward]:IsShown() and ns.Display.arrows[reward].texture:find('Upgrade.tga', 1, true))
	ns.Upgrades:Dismiss(); Flush()
end)

Test('/gw upgrades explains a scan with no upgrades', function()
	inventory[0][1] = cloth8; wipe(messages)
	SlashCmdList.GEARWISE('upgrades'); Flush()
	assert(not ns.Upgrades.current)
	local output = table.concat(messages, '\n')
	assert(output:find('No bag upgrades for Frost', 1, true) and output:find('1 similar', 1, true))
end)

Test('manual inventory review survives missing hyperlinks until they load', function()
	inventory[0][1] = cloth10
	ns.Upgrades.counts = ns.Upgrades:Snapshot()
	missingLink = true; wipe(messages)
	SlashCmdList.GEARWISE('upgrades')
	assert(ns.Upgrades.reviewRequested and table.concat(messages):find('Waiting for inventory item data', 1, true))
	missingLink = false; Flush()
	assert(ns.Upgrades.current.link == cloth10)
	assert(not ns.Upgrades.reviewRequested and table.concat(messages):find('Found 1 bag upgrade', 1, true))
	ns.Upgrades:Dismiss(); Flush()
end)

Test('manual review reports comparisons still loading and opens when data arrives', function()
	local delayed = AddItem(352, {RESISTANCE0_NAME = 10}, 'INVTYPE_CHEST', 4, 1, {loading = true})
	inventory[0][1] = delayed; wipe(messages)
	SlashCmdList.GEARWISE('upgrades')
	assert(not ns.Upgrades.current and table.concat(messages):find('1 comparison is still loading', 1, true))
	items[352].loading = false; Fire('GET_ITEM_INFO_RECEIVED'); Flush()
	assert(ns.Upgrades.current.link == delayed)
	ns.Upgrades:Dismiss(); Flush()
end)

Test('Skinning Knife has no red shade, combat arrow, or equip recommendation', function()
	local knife = AddItem(7005, {ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 1.25}, 'INVTYPE_WEAPON', 2, 14)
	inventory[0][1] = knife; SlashCmdList.GEARWISE('upgrades'); Flush()
	assert(ns.Compare:Get(knife).status == 'irrelevant')
	assert(not ns.Upgrades.current)
	ns.Display:Update()
	assert(not ns.Display.arrows[bagButton]:IsShown())
	assert(not ns.Display.shades[bagButton] or not ns.Display.shades[bagButton]:IsShown())
end)

Test('screenshot: level-5 Shadow Priest gets an upgrade arrow and +0.8 DPS for Forsaken Maul', function()
	UnitClass = function() return 'Priest', 'PRIEST' end
	UnitLevel = function() return 5 end
	local worn = AddItem(36, {ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 2 / 1.9}, 'INVTYPE_WEAPONMAINHAND', 2, 4,
		{name = 'Worn Mace', sell = 5, lines = {
			{leftText = 'Worn Mace'}, {leftText = 'Main Hand', rightText = 'Mace'},
			{leftText = '1 - 3 Damage', rightText = 'Speed 1.90'}, {leftText = '(1.1 damage per second)'}}})
	local maul = AddItem(3269, {ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 3.5 / 1.9}, 'INVTYPE_WEAPONMAINHAND', 2, 4,
		{name = 'Forsaken Maul', sell = 25, lines = {
			{leftText = 'Forsaken Maul'}, {leftText = 'Main Hand', rightText = 'Mace'},
			{leftText = '2 - 5 Damage', rightText = 'Speed 1.90'}, {leftText = '(1.8 damage per second)'}}})
	equipped[16], equipped[17], equipped[18] = worn, nil, nil
	ns:Invalidate(true); Flush()
	local result = ns.Compare:Get(maul)
	assert(result.status == 'upgrade', 'Expected upgrade, got ' .. result.status)
	assert(math.abs(result.changes.dps - (3.5 / 1.9 - 2 / 1.9)) < 0.00001)
	assert(table.concat(ns.Display:Changes(result)):find('+0.8 Weapon DPS', 1, true))
	rewards.choice1 = maul; ns.Display:Update()
	assert(ns.Display.arrows[reward]:IsShown() and ns.Display.arrows[reward].texture:find('Upgrade.tga', 1, true))
end)

Test('precise DPS falls back to damage and speed when GetItemStats omits it', function()
	items[36].noStatsAPI, items[3269].noStatsAPI = true, true
	ns.Items:Clear(); ns.Compare:Clear()
	local result = ns.Compare:Get('item:3269')
	assert(result.status == 'upgrade')
	assert(table.concat(ns.Display:Changes(result)):find('+0.8 Weapon DPS', 1, true))
	assert(math.abs(ns.Items:Get('item:36').stats.dps - 2 / 1.9) < 0.00001)
	items[36].noStatsAPI, items[3269].noStatsAPI = nil, nil
	ns.Items:Clear(); ns.Compare:Clear()
end)

Test('the same quest reward can show both an upgrade arrow and a gold coin', function()
	rewards.choice1 = 'item:3269'
	rewards.choice2 = AddItem(360, {ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 3}, 'INVTYPE_2HWEAPON', 2, 8, {sell = 20})
	ns.Display:Update()
	assert(ns.Display.arrows[reward]:IsShown() and ns.Display.coins[reward]:IsShown())
	assert(ns.Display.arrows[reward].point[1] == 'TOPRIGHT' and ns.Display.coins[reward].point[1] == 'BOTTOMLEFT')
	items[360].sell = 52; ns.Display:Update()
	assert(ns.Display.arrows[reward]:IsShown() and ns.Display.coins[second]:IsShown())
	assert(not ns.Display.coins[reward]:IsShown())
end)

Test('a known vendor-price recommendation stays visible while gear stats are loading', function()
	local tooltip = C_TooltipInfo.GetHyperlink
	C_TooltipInfo.GetHyperlink = function(link)
		if link == 'item:360' then return nil end
		return tooltip(link)
	end
	ns.Items:Clear(); ns.Compare:Clear(); ns.Display:Update()
	assert(ns.Compare:Get('item:360').status == 'pending')
	assert(ns.Display.coins[second]:IsShown() and ns.Display.arrows[reward]:IsShown())
	C_TooltipInfo.GetHyperlink = tooltip
	ns.Items:Clear(); ns.Compare:Clear()
end)

Test('early caster melee scoring preserves feral priorities and expires at level 20', function()
	UnitClass = function() return 'Druid', 'DRUID' end
	UnitLevel = function() return 10 end
	local feral = ns.Profiles:Detect()
	assert(feral.feral and not feral.meleeDPS)
	UnitClass = function() return 'Priest', 'PRIEST' end
	UnitLevel = function() return 20 end
	local priest = ns.Profiles:Detect()
	assert(not priest.meleeDPS)
	UnitLevel = function() return 5 end
	assert(ns.Profiles:Detect().meleeDPS > 0)
end)

print(('All %d behavioral checks passed under Lua 5.1.'):format(passed))
