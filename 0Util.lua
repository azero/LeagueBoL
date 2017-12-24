local myMenu = nil
local scriptVersion = "4"
local isDebug = true
local m = nil

function spellReady(slot)
    return (myHero:CanUseSpell(slot) == READY)
end

function TARGETING_UnitValid(unit)
	if unit and ValidTarget(unit) and not unit.isDead then return true end
	return false
end

function FindSlotByName(name)
	if name ~= nil then
		for i=0, 12 do
			if string.lower(myHero:GetSpellData(i).name) == string.lower(name) then
				return i
			end
		end
	end  
	return nil
end

function PrettyPrint(message, isDebug)
	if isDebug and not showDebug then return end
	if m == message then
		return
	end
	print("<font color=\"#FF5733\">[<b><i>0Util</i></b>]</font> <font color=\"#3393FF\">" .. message .. "</font>")
	m = message
end

--
--
--START: Update
--
--
local AUTOUPDATE = true
local UPDATE_HOST = "raw.githubusercontent.com"
local UPDATE_PATH = "/azero/LeagueBoL/master/0Util.lua".."?rand="..math.random(1,10000)
local UPDATE_FILE_PATH = SCRIPT_PATH..GetCurrentEnv().FILE_NAME
local UPDATE_URL = "https://"..UPDATE_HOST..UPDATE_PATH

if AUTOUPDATE then
	local ServerData = GetWebResult(UPDATE_HOST, "/azero/LeagueBoL/master/0Util.ver")
	if ServerData then
		ServerVersion = type(tonumber(ServerData)) == "number" and tonumber(ServerData) or nil
		if ServerVersion then
			if tonumber(scriptVersion) < ServerVersion then
				PrettyPrint("New version! Updating to: " .. ServerVersion)
				DelayAction(function() DownloadFile(UPDATE_URL, UPDATE_FILE_PATH, function () PrettyPrint("Successfully updated. ("..scriptVersion.." => "..ServerVersion.."), press F9 twice to load the updated version.") end) end, 3)
			end
		end
	else
		PrettyPrint("Error: Could not find version information.", false)
	end
end

function NewMessage()
	local ServerData = GetWebResult(UPDATE_HOST, "/azero/LeagueBoL/master/0Util.msg")
	if ServerData then
		PrettyPrint(ServerData)
	end
end
--
--
--END: Update
--
--

--
--
--START: Potions
--
--
function POTIONS_Menu()
	myMenu:addSubMenu("--[[ Potions ]]--", "Potion")
		myMenu.Potion:addParam("use", "Use Potions", SCRIPT_PARAM_ONOFF, true)
		myMenu.Potion:addParam("hp", "HP Percent to Potion", SCRIPT_PARAM_SLICE, 45, 0, 100, 0)
		myMenu.Potion:addParam("info2", " ", SCRIPT_PARAM_INFO, "")
		myMenu.Potion:addParam("healthpot", "Health Potion", SCRIPT_PARAM_ONOFF, true)
		myMenu.Potion:addParam("healthcookie", "Health Cookie", SCRIPT_PARAM_ONOFF, true)
		myMenu.Potion:addParam("hunterspot", "Hunters Potion", SCRIPT_PARAM_ONOFF, true)
		myMenu.Potion:addParam("refillablepot", "Refillable Potion", SCRIPT_PARAM_ONOFF, true)
		myMenu.Potion:addParam("corruptingpot", "Corrupting Potion", SCRIPT_PARAM_ONOFF, true)
end

local lastPotionTime = os.clock()
local lastPotionDur = 0
function PORIONS_Run()
	if myMenu.Potion.use and os.clock() - lastPotionTime > lastPotionDur and not InFountain() and (myHero.health*100)/myHero.maxHealth < myMenu.Potion.hp then
		for SLOT = ITEM_1, ITEM_6 do
			if myHero:GetSpellData(SLOT).name == "RegenerationPotion" and myMenu.Potion.healthpot then
				PrettyPrint("Using potion [Health Potion]", true)
				CastSpell(SLOT)
				lastPotionDur = 15
				lastPotionTime = os.clock()
				return true
			elseif myHero:GetSpellData(SLOT).name == "ItemMiniRegenPotion" and myMenu.Potion.healthcookie then
				PrettyPrint("Using potion [Cookie]", true)
				CastSpell(SLOT)
				lastPotionDur = 15
				lastPotionTime = os.clock()
				return true
			elseif myHero:GetSpellData(SLOT).name == "ItemCrystalFlaskJungle" and myMenu.Potion.hunterspot then
				PrettyPrint("Using potion [Hunters Potion]", true)
				CastSpell(SLOT)
				lastPotionDur = 8
				lastPotionTime = os.clock()
				return true
			elseif myHero:GetSpellData(SLOT).name == "ItemCrystalFlask" and myMenu.Potion.refillablepot then
				PrettyPrint("Using potion [Refillable Potion]", true)
				CastSpell(SLOT)
				lastPotionDur = 12
				lastPotionTime = os.clock()
				return true
			elseif myHero:GetSpellData(SLOT).name == "ItemDarkCrystalFlask" and myMenu.Potion.corruptingpot then
				PrettyPrint("Using potion [Corrupting Potion]", true)
				CastSpell(SLOT)
				lastPotionDur = 12
				lastPotionTime = os.clock()
				return true
			end
		end
	end
	return false
end
--
--
--END: Potions
--
--


--
--
--START: Smite
--
--
local smiteList = {"summonersmite", "s5_summonersmiteplayerganker", "s5_summonersmiteduel"}
local smiteSlot = nil
local dmgSmite = false

function SMITE_Menu()
	SMITE_Slot()
	myMenu:addSubMenu("--[[ Smite ]]--", "Smite")
		myMenu.Smite:addParam("dragon", "Smite Dragon", SCRIPT_PARAM_ONOFF, true)
		myMenu.Smite:addParam("baron", "Smite Baron", SCRIPT_PARAM_ONOFF, true)
		myMenu.Smite:addParam("rift", "Smite Rift", SCRIPT_PARAM_ONOFF, true)
		myMenu.Smite:addParam("info2", " ", SCRIPT_PARAM_INFO, "")
		myMenu.Smite:addParam("red", "Smite Red", SCRIPT_PARAM_ONOFF, true)
		myMenu.Smite:addParam("blue", "Smite Blue", SCRIPT_PARAM_ONOFF, true)
		myMenu.Smite:addParam("info2", " ", SCRIPT_PARAM_INFO, "")
		myMenu.Smite:addParam("krugs", "Smite Krugs", SCRIPT_PARAM_ONOFF, false)
		myMenu.Smite:addParam("gromp", "Smite Gromp", SCRIPT_PARAM_ONOFF, false)
		myMenu.Smite:addParam("wolves", "Smite Wolves", SCRIPT_PARAM_ONOFF, false)
		myMenu.Smite:addParam("raptors", "Smite Raptors", SCRIPT_PARAM_ONOFF, false)
		myMenu.Smite:addParam("info2", " ", SCRIPT_PARAM_INFO, "")
		myMenu.Smite:addParam("smite", "Use Smite", SCRIPT_PARAM_ONKEYTOGGLE, true, GetKey("H"))
end

function SMITE_Slot()
	for i=1, 3 do
		if FindSlotByName(smiteList[i]) ~= nil then
			smiteSlot = FindSlotByName(smiteList[i])
			if i == 2 or i == 3 then
				dmgSmite = true
			else
				dmgSmite = false
			end
		end
	end
	if smiteSlot ~= nil then
		PrettyPrint("Smite detected!", false)
	end
end

function SMITE_Damage(unit)
	if smiteSlot and myMenu.Smite.smite then
		local SmiteDamage
		if myHero.level <= 4 then
		SmiteDamage = 370 + (myHero.level*20)
		end
		if myHero.level > 4 and myHero.level <= 9 then
		SmiteDamage = 330 + (myHero.level*30)
		end
		if myHero.level > 9 and myHero.level <= 14 then
		SmiteDamage = 240 + (myHero.level*40)
		end
		if myHero.level > 14 then
		SmiteDamage = 100 + (myHero.level*50)
		end
		return SmiteDamage
	end
end

function SMITE_Run()
	if smiteSlot == nil or not myMenu.Smite.smite then return false end
	local SmiteDmg = SMITE_Damage()
	for _, minion in pairs(minionManager(MINION_JUNGLE, 500, myHero, MINION_SORT_MAXHEALTH_DEC).objects) do
		if not minion.dead and minion.visible and ValidTarget(minion, 500) then
			if (myMenu.Smite.red and string.lower(minion.charName):find("red")) then
				if spellReady(smiteSlot) and GetDistance(myHero, minion) <= 500 and SmiteDmg >= minion.health then
					CastSpell(smiteSlot, minion)
					return true
				end
			elseif (myMenu.Smite.blue and  string.lower(minion.charName):find("blue")) then
				if spellReady(smiteSlot) and GetDistance(myHero, minion) <= 500 and SmiteDmg >= minion.health then
					CastSpell(smiteSlot, minion)
					return true
				end
			elseif (myMenu.Smite.wolf and string.lower(minion.charName):find("wolves")) then
				if spellReady(smiteSlot) and GetDistance(myHero, minion) <= 500 and SmiteDmg >= minion.health then
					CastSpell(smiteSlot, minion)
					return true
				end
			elseif (myMenu.Smite.dragon and  string.lower(minion.charName):find("dragon")) then
				if spellReady(smiteSlot) and GetDistance(myHero, minion) <= 500 and SmiteDmg >= minion.health then
					CastSpell(smiteSlot, minion)
					return true
				end
			elseif (myMenu.Smite.baron and  string.lower(minion.charName):find("baron")) then
				if spellReady(smiteSlot) and GetDistance(myHero, minion) <= 500 and SmiteDmg >= minion.health then
					CastSpell(smiteSlot, minion)
					return true
				end
			elseif (myMenu.Smite.rift and  string.lower(minion.charName):find("rift"))  then
				if spellReady(smiteSlot) and GetDistance(myHero, minion) <= 500 and SmiteDmg >= minion.health then
					CastSpell(smiteSlot, minion)
					return true
				end
			elseif (myMenu.Smite.krugs and  string.lower(minion.charName):find("krugs"))  then
				if spellReady(smiteSlot) and GetDistance(myHero, minion) <= 500 and SmiteDmg >= minion.health then
					CastSpell(smiteSlot, minion)
					return true
				end
			elseif (myMenu.Smite.gromp and  string.lower(minion.charName):find("grump")) then
				if spellReady(smiteSlot) and GetDistance(myHero, minion) <= 500 and SmiteDmg >= minion.health then
					CastSpell(smiteSlot, minion)
					return true
				end
			elseif (myMenu.Smite.raptors and  string.lower(minion.charName):find("raptor")) then
				if spellReady(smiteSlot) and GetDistance(myHero, minion) <= 500 and SmiteDmg >= minion.health then
					CastSpell(smiteSlot, minion)
					return true
				end
			end
		end
	end
	return false
end

function SMITE_Draw()
	if smiteSlot == nil or not myMenu.Smite.smite then return end
	local SmiteDmg = SMITE_Damage()
	for _, minion in pairs(minionManager(MINION_JUNGLE, 750, myHero, MINION_SORT_MAXHEALTH_DEC).objects) do
		if not minion.dead and minion.visible and ValidTarget(minion, 750) then
			if spellReady(smiteSlot) and GetDistance(myHero, minion) <= 750 and SmiteDmg >= minion.health then
				local posMinion = WorldToScreen(D3DXVECTOR3(minion.x, minion.y, minion.z))
				DrawText("Smite Now!", 20, posMinion.x, posMinion.y, ARGB(255,255,0,0))
			end
		end
	end
end

--
--
--END: SMITE_Damage
--
--

--
--
--START: Ignite
--
--

local igniteSlot = nil
function IGNITE_Menu()
	igniteSlot = FindSlotByName("summonerdot")
	myMenu:addSubMenu("--[[ Ignite ]]--", "Ignite")
		myMenu.Ignite:addParam("ignite", "Use Ignite", SCRIPT_PARAM_ONKEYTOGGLE, true, GetKey("H"))
	if igniteSlot ~= nil then
		PrettyPrint("Ignite detected!", false)
	end
end

function IGNITE_Run()
	if igniteSlot == nil or not myMenu.Ignite.ignite then return false end
	for i,enemy in pairs(GetEnemyHeroes()) do
		if TARGETING_UnitValid(enemy) and igniteSlot and GetDistance(myHero, enemy) <= 600 and ((50 + (20*myHero.level))) >= enemy.health and igniteSlot ~= nil and myHero:CanUseSpell(igniteSlot) == READY then
			CastSpell(igniteSlot, enemy)
			PrettyPrint("Ignite: [" .. enemy.charName .. "]", true)
			return true
		end
	end
	return false
end
--
--
--END: Ignite
--
--

function OnLoad()
	PrettyPrint("Welcome To Zer0 Utility " .. GetUser() .. " - Version: " .. scriptVersion .. " - By: AZer0", false)
	PrettyPrint("This script is still in BETA please let me know any errors you may find.", false)
	
	NewMessage()
	
	myMenu = scriptConfig("--[[ Zer0 Utility ]]--", "ZUtil")
	
	SMITE_Menu()
	IGNITE_Menu()
	POTIONS_Menu()
end

function OnDraw()
	SMITE_Draw()
end

function OnTick()
	if SMITE_Run() then return true end
	if IGNITE_Run() then return true end
	if PORIONS_Run() then return true end
end