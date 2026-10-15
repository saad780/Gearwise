local ns, tests = Gearwise, {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end
local function eq(actual, expected, context)
	assert(actual == expected, (context or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function near(actual, expected) assert(math.abs(actual - expected) < 0.001, tostring(actual) .. " != " .. expected) end
local function contains(text, pattern) assert(text:find(pattern, 1, true), "missing: " .. pattern .. " in " .. text) end
local function Reset(class, spec, level)
	mock.items, mock.equipped, mock.bags, mock.uncachedSlots = {}, {}, {}, nil
	mock.class, mock.level, mock.talents = class or "MAGE", level or 25, { 0, 0, 0 }
	mock.dualWield, mock.quest, mock.questLog, mock.combat = false, nil, nil, false
	ns.db.spec, ns.db.mode, ns.db.bags, ns.db.quests, ns.db.tooltips = spec or "auto", "auto", true, true, true
	ns.Items:Clear(); ns.Compare:Clear(); wipe(ns.Display.buttons)
	ns.profile = ns.Profiles:Detect()
	GameTooltip.owner = nil
	GameTooltip:ClearLines(); ItemRefTooltip:ClearLines()
	QuestInfoFrame = { questLog = false }
	QuestInfoRewardsFrame = nil
	ContainerFrameCombinedBags = nil
end
local nextID = 100
local function Item(stats, options)
	nextID = nextID + 1
	local link = "item:" .. nextID
	local data = { stats = stats or {} }
	for key, value in pairs(options or {}) do data[key] = value end
	mock.items[link] = data
	return link, data
end
local function Weapon(dps, loc, subclass, stats)
	stats = stats or {}; stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT = dps
	return Item(stats, { classID = 2, subclassID = subclass or 7, loc = loc or "INVTYPE_WEAPON" })
end
local function BagButton(bag, slot, name)
	local button = CreateFrame("Button", name, UIParent)
	button:SetID(slot)
	button.bag = bag
	button.Icon = button:CreateTexture()
	return button
end

test("startup stays quiet and registers settings without touching another addon", function()
	eq(#mock.output, 0)
	assert(ns.Options.category)
	assert(SlashCmdList.GEARWISE)
	eq(SharpiesGearJudge, nil)
end)

test("every class and all 29 builds produce sensible stat upgrades and downgrades", function()
	local count = 0
	for class, profiles in pairs(ns.Profiles.classes) do
		for _, profile in ipairs(profiles) do
			Reset(class, profile.key)
			local key = (class == "HUNTER" or class == "ROGUE") and "ITEM_MOD_AGILITY_SHORT" or "ITEM_MOD_STRENGTH_SHORT"
			if (profile.weights.int or 0) > 1 then key = "ITEM_MOD_INTELLECT_SHORT" end
			mock.equipped[5] = Item({ [key] = 5 })
			local better = Item({ [key] = 10 })
			local worse = Item({ [key] = 1 })
			eq(ns.Compare:Get(better).status, "upgrade", class .. "/" .. profile.key)
			eq(ns.Compare:Get(worse).status, "downgrade", class .. "/" .. profile.key)
			count = count + 1
		end
	end
	eq(count, 29)
end)

test("automatic detection follows purchased talent ranks for all nine classes", function()
	for class, profiles in pairs(ns.Profiles.classes) do
		for tab = 1, 3 do
			Reset(class)
			mock.talents[tab] = 15
			mock.talents[tab % 3 + 1] = 5
			local profile = ns.Profiles:Detect()
			eq(profile.key, profiles[tab].key, class .. " talent tree " .. tab)
			eq(profile.source, "Auto")
		end
	end
end)

test("no talents uses a leveling default, while manual healer and bear overrides persist", function()
	Reset("PRIEST", "auto", 5)
	eq(ns.profile.key, "shadow")
	eq(ns.profile.source, "No talents yet")
	Reset("DRUID", "bear", 25)
	eq(ns.profile.key, "bear"); eq(ns.profile.source, "Manual")
	mock.talents = { 20, 0, 0 }
	ns:Invalidate(false)
	eq(ns.profile.key, "bear", "manual choice survives talent updates")
	Reset("SHAMAN", "restoration")
	eq(ns.profile.role, "healer")
end)

test("modern specialization and Classic tab-point fallbacks are supported", function()
	Reset("MAGE")
	local oldCount, oldInfo = GetNumTalents, GetTalentInfo
	GetNumTalents, GetTalentInfo = nil, nil
	GetTalentTabInfo = function(tab) return "Tree", 12345, tab == 2 and 15 or 0 end
	eq(ns.Profiles:Detect().key, "fire")
	GetTalentTabInfo = nil
	GetSpecialization = function() return 1 end
	GetSpecializationInfo = function() return 62 end
	eq(ns.Profiles:Detect().key, "arcane")
	GetNumTalents, GetTalentInfo, GetSpecialization, GetSpecializationInfo = oldCount, oldInfo, nil, nil
end)

test("leveling increases recovery and health value, then switches at level 60", function()
	Reset("MAGE", "frost", 25)
	local low = ns.profile
	Reset("MAGE", "frost", 60)
	assert(not ns.profile.leveling)
	assert(low.weights.sta > ns.profile.weights.sta)
	assert(low.weights.spi > ns.profile.weights.spi)
	ns:SetOption("mode", "leveling")
	assert(ns.profile.leveling)
end)

test("talent updates recalculate comparisons instead of retaining the old build", function()
	Reset("PALADIN")
	mock.talents = { 0, 0, 16 }
	mock.Fire("PLAYER_TALENT_UPDATE")
	eq(ns.profile.key, "retribution")
	local old = Item({ ITEM_MOD_STRENGTH_SHORT = 10 })
	local candidate = Item({ ITEM_MOD_INTELLECT_SHORT = 10, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 10 })
	mock.equipped[5] = old
	eq(ns.Compare:Get(candidate).status, "downgrade")
	mock.talents = { 16, 0, 0 }
	mock.Fire("PLAYER_TALENT_UPDATE")
	eq(ns.profile.key, "holy")
	eq(ns.Compare:Get(candidate).status, "upgrade")
end)

test("mixed stats show an upgrade when useful stats beat the losses, not item level", function()
	Reset("MAGE", "frost")
	mock.equipped[5] = Item({ ITEM_MOD_STRENGTH_SHORT = 20, ITEM_MOD_STAMINA_SHORT = 3 }, { level = 20 })
	local candidate = Item({ ITEM_MOD_INTELLECT_SHORT = 5, ITEM_MOD_STAMINA_SHORT = 2 }, { level = 1 })
	local result = ns.Compare:Get(candidate)
	eq(result.status, "upgrade")
	eq(result.changes.str, -20); eq(result.changes.int, 5); eq(result.changes.sta, -1)
end)

test("rings and trinkets compare against the weaker eligible equipped slot", function()
	for _, case in ipairs({ { "INVTYPE_FINGER", 11, 12 }, { "INVTYPE_TRINKET", 13, 14 } }) do
		Reset()
		mock.equipped[case[2]] = Item({ ITEM_MOD_INTELLECT_SHORT = 15 }, { loc = case[1] })
		mock.equipped[case[3]] = Item({ ITEM_MOD_INTELLECT_SHORT = 3 }, { loc = case[1] })
		local candidate = Item({ ITEM_MOD_INTELLECT_SHORT = 8 }, { loc = case[1] })
		local result = ns.Compare:Get(candidate)
		eq(result.status, "upgrade"); eq(result.slot, case[3])
		eq(result.changes.int, 5)
	end
end)

test("unique-equipped copies replace their matching ring rather than illegally filling the other slot", function()
	Reset()
	local worn = Item({ ITEM_MOD_INTELLECT_SHORT = 15 }, { loc = "INVTYPE_FINGER", lines = { "Ring", "Unique-Equipped" } })
	mock.equipped[11] = worn
	mock.equipped[12] = Item({ ITEM_MOD_INTELLECT_SHORT = 1 }, { loc = "INVTYPE_FINGER" })
	local result = ns.Compare:Get(worn)
	eq(result.slot, 11); eq(result.status, "equal")
end)

test("unique categories apply across slots and honor their allowed count", function()
	Reset()
	mock.equipped[2] = Item({ ITEM_MOD_INTELLECT_SHORT = 1 }, { loc = "INVTYPE_NECK", limit = 42, limitMax = 1 })
	local candidate = Item({ ITEM_MOD_INTELLECT_SHORT = 20 }, { loc = "INVTYPE_FINGER", limit = 42, limitMax = 1 })
	eq(ns.Compare:Get(candidate).status, "unusable")
end)

test("a duplicate non-unique bag ring is still allowed to replace the weaker ring", function()
	Reset()
	local ring = Item({ ITEM_MOD_INTELLECT_SHORT = 15 }, { loc = "INVTYPE_FINGER" })
	mock.equipped[11] = ring
	mock.equipped[12] = Item({ ITEM_MOD_INTELLECT_SHORT = 2 }, { loc = "INVTYPE_FINGER" })
	local result = ns.Compare:Get(ring)
	eq(result.slot, 12); eq(result.status, "upgrade")
end)

test("two-handed weapons include the lost off-hand stats in their comparison", function()
	Reset("WARRIOR", "arms")
	mock.equipped[16] = Weapon(10)
	mock.equipped[17] = Item({ RESISTANCE0_NAME = 300 }, { loc = "INVTYPE_SHIELD", subclassID = 6 })
	local small = Weapon(10.2, "INVTYPE_2HWEAPON", 8)
	local large = Weapon(20, "INVTYPE_2HWEAPON", 8)
	eq(ns.Compare:Get(small).status, "downgrade")
	local result = ns.Compare:Get(large)
	eq(result.status, "upgrade"); eq(#result.oldLinks, 2)
	eq(result.changes.armor, -300)
end)

test("dual-wield weapons choose the useful hand and scale off-hand DPS correctly", function()
	Reset("ROGUE", "combat")
	mock.dualWield = true
	mock.equipped[16] = Weapon(10)
	mock.equipped[17] = Weapon(5)
	local candidate = Weapon(7)
	local result = ns.Compare:Get(candidate)
	eq(result.slot, 17); eq(result.status, "upgrade")
	near(result.delta, 2 * ns.profile.meleeDPS * 0.5)
end)

test("an off-hand alone is not advertised as an upgrade to a two-handed setup", function()
	Reset("MAGE", "frost")
	mock.equipped[16] = Weapon(10, "INVTYPE_2HWEAPON", 10, { ITEM_MOD_INTELLECT_SHORT = 3 })
	local offhand = Item({ ITEM_MOD_INTELLECT_SHORT = 20 }, { loc = "INVTYPE_HOLDABLE", subclassID = 0 })
	eq(ns.Compare:Get(offhand).status, "unsupported")
end)

test("untrained dual wield and shield builds do not get invalid weapon recommendations", function()
	Reset("ROGUE", "combat", 5)
	local offhand = Weapon(50, "INVTYPE_WEAPONOFFHAND")
	eq(ns.Compare:Get(offhand).status, "unusable")
	Reset("WARRIOR", "protection")
	local twohand = Weapon(50, "INVTYPE_2HWEAPON", 8)
	eq(ns.Compare:Get(twohand).status, "unusable")
end)

test("hunter ranged DPS matters while melee weapons are evaluated as stat sticks", function()
	Reset("HUNTER", "beast_mastery")
	mock.equipped[18] = Weapon(5, "INVTYPE_RANGED", 2)
	local bow = Weapon(10, "INVTYPE_RANGED", 2)
	eq(ns.Compare:Get(bow).status, "upgrade")
	mock.equipped[16] = Weapon(20, "INVTYPE_2HWEAPON", 8, { ITEM_MOD_AGILITY_SHORT = 5 })
	local melee = Weapon(50, "INVTYPE_2HWEAPON", 8, { ITEM_MOD_AGILITY_SHORT = 1 })
	eq(ns.Compare:Get(melee).status, "downgrade")
end)

test("feral weapons use stats, not white weapon DPS; early druids still value melee damage", function()
	Reset("DRUID", "feral", 25)
	mock.equipped[16] = Weapon(5, "INVTYPE_2HWEAPON", 10, { ITEM_MOD_AGILITY_SHORT = 5 })
	local candidate = Weapon(50, "INVTYPE_2HWEAPON", 10, { ITEM_MOD_AGILITY_SHORT = 1 })
	eq(ns.Compare:Get(candidate).status, "downgrade")
	Reset("DRUID", "feral", 5)
	assert(ns.profile.meleeDPS > 0)
	Reset("DRUID", "bear", 15)
	eq(ns.profile.meleeDPS, nil, "Bear Form does not use weapon DPS")
end)

test("wands have meaningful leveling value without giving casters melee DPS recommendations", function()
	Reset("PRIEST", "shadow", 15)
	mock.equipped[18] = Weapon(5, "INVTYPE_RANGEDRIGHT", 19)
	local wand = Weapon(10, "INVTYPE_RANGEDRIGHT", 19)
	eq(ns.Compare:Get(wand).status, "upgrade")
	mock.equipped[16] = Weapon(5, "INVTYPE_2HWEAPON", 10, { ITEM_MOD_INTELLECT_SHORT = 5 })
	local staff = Weapon(50, "INVTYPE_2HWEAPON", 10, { ITEM_MOD_INTELLECT_SHORT = 1 })
	eq(ns.Compare:Get(staff).status, "downgrade")
end)

test("class armor, weapon, relic and level requirements suppress arrows", function()
	Reset("MAGE", "frost", 25)
	for _, options in ipairs({ { subclassID = 4 }, { classID = 2, subclassID = 0, loc = "INVTYPE_WEAPON" },
		{ level = 40 }, { subclassID = 9, loc = "INVTYPE_RELIC" }, { subclassID = 6, loc = "INVTYPE_SHIELD" } }) do
		local candidate = Item({ ITEM_MOD_INTELLECT_SHORT = 100 }, options)
		eq(ns.Compare:Get(candidate).status, "unusable")
	end
	Reset("HUNTER", "beast_mastery", 25)
	local mail = Item({ ITEM_MOD_AGILITY_SHORT = 100 }, { subclassID = 3 })
	eq(ns.Compare:Get(mail).status, "unusable")
	mock.level = 40; ns:Invalidate(false)
	eq(ns.Compare:Get(mail).status, "upgrade")
end)

test("red profession and class requirements are read from the actual item tooltip", function()
	Reset()
	local item = Item({ ITEM_MOD_INTELLECT_SHORT = 100 }, { lines = {
		"Goggles", { leftText = "Requires Engineering (150)", leftColor = { r = 1, g = 0.1, b = 0.1 } } } })
	eq(ns.Compare:Get(item).status, "unusable")
end)

test("uncached candidate and equipped items wait for data instead of scoring zero", function()
	Reset()
	local worn, wornData = Item({ ITEM_MOD_INTELLECT_SHORT = 10 }, { uncached = true })
	local candidate = Item({ ITEM_MOD_INTELLECT_SHORT = 5 })
	mock.equipped[5] = worn
	eq(ns.Compare:Get(candidate).status, "pending")
	wornData.uncached = false
	mock.Fire("GET_ITEM_INFO_RECEIVED", tonumber(worn:match("%d+")), true)
	eq(ns.Compare:Get(candidate).status, "downgrade")
	local missing = Item({}, { uncached = true })
	eq(ns.Compare:Get(missing).status, "pending")
	local id = tonumber(missing:match("%d+"))
	local calls = mock.requests[id]
	ns.Compare:Get(missing)
	eq(mock.requests[id], calls, "requests are throttled")
end)

test("an equipped slot whose link is still loading is not treated as empty", function()
	Reset()
	mock.uncachedSlots = { [5] = 9000 }
	local item = Item({ ITEM_MOD_INTELLECT_SHORT = 10 })
	eq(ns.Compare:Get(item).status, "pending")
end)

test("missing stats or tooltip data also wait, and secret values never crash the engine", function()
	Reset()
	for _, options in ipairs({ { missingStats = true }, { missingTooltip = true } }) do
		local item = Item({ ITEM_MOD_INTELLECT_SHORT = 10 }, options)
		eq(ns.Compare:Get(item).status, "pending")
	end
	local secret = { secret = true }
	local item = Item({ ITEM_MOD_INTELLECT_SHORT = secret }, { lines = { { leftText = secret } } })
	assert(ns.Compare:Get(item))
	eq(ns.Compare:Get(secret).status, "irrelevant")
end)

test("classic tooltip stats and weapon DPS supplement API stats without doubling attributes", function()
	Reset()
	local item = Item({ ITEM_MOD_INTELLECT_SHORT = 5 }, { lines = {
		"Staff", "+5 Intellect", "+3 Stamina", "Equip: Increases damage and healing done by magical spells and effects by up to 10.",
		"(8.5 damage per second)" } })
	local data = ns.Items:Get(item)
	eq(data.stats.int, 5); eq(data.stats.sta, 3); eq(data.stats.sp, 10); near(data.stats.dps, 8.5)
end)

test("unified hit and crit aliases are credited only once in Forever", function()
	Reset()
	local item = Item({ ITEM_MOD_CRIT_MELEE_RATING_SHORT = 1, ITEM_MOD_CRIT_SPELL_RATING_SHORT = 1,
		ITEM_MOD_HIT_MELEE_RATING_SHORT = 1, ITEM_MOD_HIT_SPELL_RATING_SHORT = 1 }, { lines = {
		"Equip: Improves your chance to get a critical strike by 1%.", "Equip: Improves your chance to hit by 1%." } })
	local data = ns.Items:Get(item)
	eq(data.stats.crit, 1); eq(data.stats.hit, 1)
	eq(data.stats.critRating, nil); eq(data.stats.hitRating, nil)
	near(ns.Compare:Score(data, 5, ns.profile), ns.profile.weights.crit + ns.profile.weights.hit)
end)

test("healing damage conversion is counted once and school-specific damage follows the build", function()
	Reset("MAGE", "frost")
	local heal = Item({ ITEM_MOD_SPELL_HEALING_DONE_SHORT = 30 })
	local power = Item({ ITEM_MOD_SPELL_POWER_SHORT = 10, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 10 })
	near(ns.Compare:Score(ns.Items:Get(heal), 5, ns.profile), ns.Compare:Score(ns.Items:Get(power), 5, ns.profile))
	local frost = Item({ ITEM_MOD_FROST_DAMAGE_SHORT = 10 })
	local fire = Item({ ITEM_MOD_FIRE_DAMAGE_SHORT = 10 })
	assert(ns.Compare:Score(ns.Items:Get(frost), 5, ns.profile) > ns.Compare:Score(ns.Items:Get(fire), 5, ns.profile))
end)

test("separate healing and damage tooltip amounts never turn all healing into spell power", function()
	Reset("MAGE", "frost")
	local link = Item({}, { lines = { "Equip: Increases healing done by spells and effects by up to 30 and damage done by spells and effects by up to 10." } })
	local item = ns.Items:Get(link)
	eq(item.stats.heal, 30); eq(item.stats.sp, 10)
	near(ns.Compare:Score(item, 5, ns.profile), 10 * ns.profile.weights.sp)
	local regen = Item({}, { lines = { "Equip: Restores 5 mana every 5 sec." } })
	eq(ns.Items:Get(regen).stats.mp5, 5)
end)

test("random suffix and enchant links keep separate item stats in the cache", function()
	Reset()
	local one = "item:9900:0:0:0:0:0:101"
	local two = "item:9900:0:0:0:0:0:102"
	mock.items[one] = { stats = { ITEM_MOD_INTELLECT_SHORT = 2 } }
	mock.items[two] = { stats = { ITEM_MOD_INTELLECT_SHORT = 12 } }
	eq(ns.Items:Get(one).stats.int, 2); eq(ns.Items:Get(two).stats.int, 12)
end)

test("tooltip stays compact, shows gains and losses, and does not duplicate or alter comparison tips", function()
	Reset()
	mock.equipped[5] = Item({ ITEM_MOD_INTELLECT_SHORT = 2, ITEM_MOD_STAMINA_SHORT = 4 })
	local candidate = Item({ ITEM_MOD_INTELLECT_SHORT = 8, ITEM_MOD_STAMINA_SHORT = 3 })
	local text = mock.ShowTooltip(candidate)
	contains(text, "Gearwise"); contains(text, "Upgrade"); contains(text, "+6 Intellect"); contains(text, "-1 Stamina")
	contains(text, "% score")
	local lines = #GameTooltip.lines
	mock.tooltipCallback(GameTooltip, { hyperlink = candidate })
	eq(#GameTooltip.lines, lines)
	local shopping = CreateFrame("GameTooltip")
	mock.ShowTooltip(candidate, shopping)
	eq(#shopping.lines, 0)
	GameTooltip.owner = CreateFrame("Button", "CharacterChestSlot")
	contains(mock.ShowTooltip(mock.equipped[5]), "Equipped")
end)

test("proc and set items keep a short stat-estimate note instead of inventing proc value", function()
	Reset()
	local candidate = Item({ ITEM_MOD_INTELLECT_SHORT = 10 }, { setID = 20, lines = {
		"Vest", "Use: Increases spell damage by 100 for 20 sec.", "Chance on hit: Deals 200 damage." } })
	local data = ns.Items:Get(candidate)
	eq(data.stats.sp, nil)
	contains(mock.ShowTooltip(candidate), "special effects and set bonuses")
end)

test("a visible tooltip updates after item data arrives and after equipment changes", function()
	Reset()
	mock.equipped[5] = Item({ ITEM_MOD_INTELLECT_SHORT = 5 })
	local candidate, data = Item({ ITEM_MOD_INTELLECT_SHORT = 10 }, { uncached = true })
	contains(mock.ShowTooltip(candidate), "Loading item data")
	data.uncached = false
	mock.Fire("GET_ITEM_INFO_RECEIVED", tonumber(candidate:match("%d+")), true)
	ns.Display:Update()
	contains(table.concat(GameTooltip.lines), "Upgrade")
	mock.equipped[5] = Item({ ITEM_MOD_INTELLECT_SHORT = 15 })
	mock.Fire("PLAYER_EQUIPMENT_CHANGED", 5)
	ns.Display:Update()
	contains(table.concat(GameTooltip.lines), "Downgrade")
end)

test("Bagnon and Blizzard bag buttons get green/red arrows that clear when reused or emptied", function()
	Reset()
	mock.equipped[5] = Item({ ITEM_MOD_INTELLECT_SHORT = 5 })
	local better = Item({ ITEM_MOD_INTELLECT_SHORT = 10 })
	local worse = Item({ ITEM_MOD_INTELLECT_SHORT = 1 })
	mock.bags[0] = { [1] = better }
	local bagnon = BagButton(0, 1, "TestBagnon")
	SetItemButtonQuality(bagnon)
	ns.Display:Update()
	contains(ns.Display.arrows[bagnon].texture, "Upgrade.tga")
	mock.bags[0][1] = worse
	ns.Display:Update()
	contains(ns.Display.arrows[bagnon].texture, "Downgrade.tga")
	mock.bags[0][1] = nil
	ns.Display:Update()
	assert(not ns.Display.arrows[bagnon]:IsShown())
	local frame = CreateFrame("Frame", "ContainerFrame1", UIParent)
	frame:SetID(0)
	local oldBlizzard = BagButton(nil, 2, "ContainerFrame1Item2")
	oldBlizzard.parent = frame
	mock.bags[0][2] = better
	ContainerFrame_Update()
	ns.Display:Update()
	contains(ns.Display.arrows[oldBlizzard].texture, "Upgrade.tga")
end)

test("cached alt bags, bank items, empty slots and unusable items never retain stale arrows", function()
	Reset()
	local better = Item({ ITEM_MOD_INTELLECT_SHORT = 10 })
	mock.bags[0] = { [1] = better }
	local button = BagButton(0, 1)
	SetItemButtonQuality(button); ns.Display:Update()
	assert(ns.Display.arrows[button]:IsShown())
	button.info = { cached = true }
	ns.Display:Update()
	assert(not ns.Display.arrows[button]:IsShown())
	button.info, button.bag = nil, 5
	ns.Display:Update()
	assert(not ns.Display.arrows[button]:IsShown())
	button.bag = 0
	mock.bags[0][1] = Item({ ITEM_MOD_INTELLECT_SHORT = 100 }, { level = 60 })
	ns.Display:Update()
	assert(not ns.Display.arrows[button]:IsShown())
end)

test("the native combined bag frame is discovered with its current bag and slot IDs", function()
	Reset()
	local candidate = Item({ ITEM_MOD_INTELLECT_SHORT = 10 })
	mock.bags[2] = { [3] = candidate }
	local button = BagButton(nil, 3)
	button.GetBagID = function() return 2 end
	ContainerFrameCombinedBags = CreateFrame("Frame", nil, UIParent)
	ContainerFrameCombinedBags.Items = { button }
	ns.Display:Discover(); ns.Display:Update()
	contains(ns.Display.arrows[button].texture, "Upgrade.tga")
	ContainerFrameCombinedBags:Hide()
end)

test("quest choice arrows use the active NPC or quest-log reward context and skip currencies", function()
	Reset()
	mock.equipped[5] = Item({ ITEM_MOD_INTELLECT_SHORT = 5 })
	local better = Item({ ITEM_MOD_INTELLECT_SHORT = 10 })
	local worse = Item({ ITEM_MOD_INTELLECT_SHORT = 1 })
	mock.quest, mock.questLog = { choice1 = better }, { choice1 = worse }
	local button = CreateFrame("Button", "QuestInfoItem1", UIParent)
	button:SetID(1); button.type, button.objectType = "choice", "item"
	button.Icon = button:CreateTexture()
	QuestInfoRewardsFrame = CreateFrame("Frame", nil, UIParent)
	QuestInfoRewardsFrame.RewardButtons = { button }
	QuestInfo_ShowRewards(); ns.Display:Update()
	contains(ns.Display.arrows[button].texture, "Upgrade.tga")
	QuestInfoFrame.questLog = true
	ns.Display:Update()
	contains(ns.Display.arrows[button].texture, "Downgrade.tga")
	button.objectType = "currency"
	ns.Display:Update()
	assert(not ns.Display.arrows[button]:IsShown())
	button:Hide()
end)

test("overlay creation waits during combat and settings immediately hide existing arrows", function()
	Reset()
	mock.bags[0] = { [1] = Item({ ITEM_MOD_INTELLECT_SHORT = 10 }) }
	local button = BagButton(0, 1)
	mock.combat = true
	SetItemButtonQuality(button); ns.Display:Update()
	eq(ns.Display.arrows[button], nil)
	mock.combat = false
	mock.Fire("PLAYER_REGEN_ENABLED"); ns.Display:Update()
	assert(ns.Display.arrows[button]:IsShown())
	ns:SetOption("bags", false)
	ns.Display:Update()
	assert(not ns.Display.arrows[button]:IsShown())
	ns:SetOption("tooltips", false)
	eq(mock.ShowTooltip(mock.bags[0][1]), "")
end)

test("simple slash commands change builds and open the settings panel", function()
	Reset("DRUID")
	SlashCmdList.GEARWISE("spec bear")
	eq(ns.db.spec, "bear"); eq(ns.profile.key, "bear")
	SlashCmdList.GEARWISE("spec invalid")
	eq(ns.db.spec, "bear")
	SlashCmdList.GEARWISE("spec auto")
	eq(ns.db.spec, "auto")
	SlashCmdList.GEARWISE("arrows off")
	eq(ns.db.bags, false); eq(ns.db.quests, false)
	SlashCmdList.GEARWISE("")
	eq(mock.openCategory, 101)
end)

local failures = 0
for _, case in ipairs(tests) do
	local ok, err = pcall(case[2])
	io.write(ok and "  ok    " or "  FAIL  ", case[1], "\n")
	if not ok then io.write("        ", tostring(err), "\n"); failures = failures + 1 end
end
io.write(("\n%d passed, %d failed\n"):format(#tests - failures, failures))
return failures
