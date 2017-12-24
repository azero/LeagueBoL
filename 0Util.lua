local myMenu = scriptConfig("--[[ Zer0 Utility ]]--", "ZUtil")
local scriptVersion = "2"
local isDebug = true
local m = nil

--
--
--START: Smite
--
--
local smiteList = {"summonersmite", "s5_summonersmiteplayerganker", "s5_summonersmiteduel"}
local smiteSlot = nil
local dmgSmite = false

function SMITE_Menu()
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
function spellReady(slot)
    return (myHero:CanUseSpell(slot) == READY)
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

function OnLoad()
	PrettyPrint("Welcome To Zer0 Utility " .. GetUser() .. " - Version: " .. scriptVersion .. " - By: AZer0", false)
	PrettyPrint("This script is still in BETA please let me know any errors you may find.")
	SMITE_Menu()
	SMITE_Slot()
end

function OnDraw()
	SMITE_Draw()
end

function OnTick()
	SMITE_Run()
end