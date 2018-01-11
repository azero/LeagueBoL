--[[
Framework Features:
-Wall Jump
-Skill Evade (no movement, just skills)
-Auto ally/self protection
-Smart targeting
-Flee Mode

Awareness
-Track summoner spell usage
-Track when summoner changes summoner spells

Champions
Fizz:
-Use Q to dash out of danger spells
-Use E to avoid spells we cant with Q
-Combo: Q/W/E/R Usage
-Harass: Q/W/E Usage
-Lane Clear: Q/W/E Usage
-Jungle Clear: Q/W/E Usage

Fizz To Do:
-E2 Logic Checks
-Q/E Options for distance to use (min and max)

---------------
Fiora:
-Q Chase
-E AA Resets
-W Block Spells
]]--

_G.ValidTarget = function(object, distance, enemyTeam)
    local enemyTeam = (enemyTeam ~= false)
    return object ~= nil and object.valid and (object.team ~= player.team) == enemyTeam and object.visible and not object.dead and object.bTargetable and (enemyTeam == false or object.bInvulnerable ~= 1) and (distance == nil or GetDistanceSqr(object) <= distance * distance)
end

local supportedChamps = {
	["Rengar"] = true,
	["Fizz"] = true,
	["Fiora"] = true
}

if not supportedChamps[myHero.charName] then
	print("<font color=\"#FF794C\"><b>Zer0 Bundle</b></font> <font color=\"#FFDFBF\"><b>Champion [".. myHero.charName .."] not currently supported.</b></font>")
else
	print("<font color=\"#FF794C\"><b>Zer0 Bundle</b></font> <font color=\"#FFDFBF\"><b>Thank you for using Zer0 Bundle.</b></font>")
end

_G.zeroBundle = {
	ChampionData = nil,
	Champion = nil,
	Menu = nil,
	OrbWalk = nil,
	Evade = nil,
	WallJump = nil,
	Prediction = nil
}

_G.zeroSettings = {
	debugging = true
}

local m = nil
local TP = nil
local VP = nil

function PrettyPrint(message, isDebug)
	if isDebug and not _G.zeroSettings.debugging then return end
	if m == message then
		return
	end
	print("<font color=\"#FF5733\">[<b><i>0 Bundle</i></b>]</font> <font color=\"#3393FF\">" .. message .. "</font>")
	m = message
end

function spellReady(slot)
    return (myHero:CanUseSpell(slot) == READY)
end

function GetDamage(target, source, spell)
	lvl = myHero.level
	ad = owner.totalDamage
	if spell == "Tiamat" then
		return source:CalcDamage(target, .6 * ad)
	elseif spell == "Hydra" then
		return source:CalcDamage(target, .6 * ad)
	elseif spell == "Ignite" then
		return 50+20*lvl
	elseif spell == "AA" then
		return source:CalcDamage(target, ad)
	else
		return 0
	end
end
--[[-----------------------------------------------------
-------------------------REPORT--------------------------
-----------------------------------------------------]]--
class("MyReporting")
function MyReporting:__init()
	
end

function MyReporting:encode(data)
	baseEnc='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    return ((data:gsub('.', function(x)
        local r,baseEnc='',x:byte()
        for i=8,1,-1 do r=r..(baseEnc%2^i-baseEnc%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return baseEnc:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

function MyReporting:makeId()
	local result = 0
	for i=0,objManager.maxObjects do
		local unit = objManager:getObject(i)
		if unit and unit.valid and unit.type == myHero.type then
			for i=1,unit.name:len() do
				result = result + unit.name:byte(i) + unit.networkID:byte(i)
			end
		end
	end
	return enc(result..myHero.charName..myHero.networkID..math.random(1,10000))
end

--[[-----------------------------------------------------
------------------------DRAWING--------------------------
-----------------------------------------------------]]--

function MyDrawArrow(from, to, color)
	DrawLineBorder3D(from.x, myHero.y, from.z, to.x, myHero.y, to.z, 2, color, 1)
end

--[[-----------------------------------------------------
-----------------------AWARENESS-------------------------
-----------------------------------------------------]]--
function TARGB(colorTable) 
  do return ARGB(colorTable[1], colorTable[2], colorTable[3], colorTable[4])
  end
end

class("MyAwareness")
function MyAwareness:__init()
	self.loaded = false
	if _G.zeroBundle.Menu then
		self.loaded = true
		
		_G.zeroBundle.Menu:addSubMenu(">> Aware Settings <<", "Aware")
			_G.zeroBundle.Menu.Aware:addParam("drawTowerRange", "Draw Tower Range", SCRIPT_PARAM_ONOFF, true)
			_G.zeroBundle.Menu.Aware:addParam("printSummoners", "Print Summoners", SCRIPT_PARAM_ONOFF, true)
			_G.zeroBundle.Menu.Aware:addParam("drawColorSummoners", "Summoner Draw color", SCRIPT_PARAM_COLOR, {255,255,0,0})
			for _, e in pairs(GetEnemyHeroes()) do
				_G.zeroBundle.Menu.Aware:addParam("printSummoners"..e.charName, "Print Summoners " .. e.charName, SCRIPT_PARAM_ONOFF, true)
			end
		self.lastPrintSum1 = nil
		self.lastPrintSum2 = nil
		self.lastHeroSum1 = nil
		self.lastHeroSum2 = nil
		self.lastHeroName1 = nil
		self.lastHeroName2 = nil
		self.lm1 = nil
		self.lm2 = nil
		
		self.summonerSpells = {}
		
		for _, e in pairs(GetEnemyHeroes()) do
			if e then
				sE = {
					["SummOne"] = {
						name = "Unknown",
						lastPrint = 0,
						summChanged = 0
					},
					["SummTwo"] = {
						name = "Unknown",
						lastPrint = 0,
						summChanged = 0
					}
				}
				self.summonerSpells[e.charName] = sE
			end
		end
		
		self.heightForName = 100
		
		self.towers = {}
		self.towerRange = 950
		self:OnLoad_TowerRange()
		
	end
end

function MyAwareness:OnDraw()
	if not self.loaded then return false end
	self.heightForName = 100
	if _G.zeroBundle.Menu.Aware.printSummoners then
		self:OnDraw_Summoners()
	end
	if _G.zeroBundle.Menu.Aware.drawTowerRange then
		self:OnDraw_TowerRange()
	end
end

function MyAwareness:OnTick()
	if not self.loaded then return false end
	if _G.zeroBundle.Menu.Aware.printSummoners then
		self:OnTick_Summoners()
	end
end

function MyAwareness:OnDraw_Summoners()
	for _, e in pairs(GetEnemyHeroes()) do
		if e and _G.zeroBundle.Menu.Aware["printSummoners" .. e.charName] then
			--Summoner is almost up
			if e:GetSpellData(SUMMONER_2).currentCd > 1 and e:GetSpellData(SUMMONER_2).currentCd < 10 and e:GetSpellData(SUMMONER_2).currentCd > 0 then
				self.heightForName = self.heightForName + 30
				DrawText(e.charName .. "'s " .. self:PrettySummoners(tostring(e:GetSpellData(SUMMONER_2).name):lower()) .." up in " .. math.round(e:GetSpellData(SUMMONER_2).currentCd, 1), 26, 150, self.heightForName, TARGB(_G.zeroBundle.Menu.Aware.drawColorSummoners))
			end
			if e:GetSpellData(SUMMONER_1).currentCd > 1 and e:GetSpellData(SUMMONER_1).currentCd < 10 and e:GetSpellData(SUMMONER_1).currentCd > 0 then
				self.heightForName = self.heightForName + 30
				DrawText(e.charName .. "'s " .. self:PrettySummoners(tostring(e:GetSpellData(SUMMONER_1).name):lower()) .." up in " .. math.round(e:GetSpellData(SUMMONER_1).currentCd, 1), 26, 150, self.heightForName, TARGB(_G.zeroBundle.Menu.Aware.drawColorSummoners))
			end
		end
	end
end

function MyAwareness:OnTick_Summoners()
	for _, e in pairs(GetEnemyHeroes()) do
		if e and _G.zeroBundle.Menu.Aware["printSummoners" .. e.charName] then
			--Just used checks
			if self.summonerSpells[e.charName]["SummTwo"].name ~= e:GetSpellData(SUMMONER_2).name and GetInGameTimer() > 60  then
				self.summonerSpells[e.charName]["SummTwo"].summChanged = GetInGameTimer()
				self.summonerSpells[e.charName]["SummTwo"].name = e:GetSpellData(SUMMONER_2).name
				self:SummonerTwoPrint("<font color=\"#FFFFFF\">" .. e.charName .. "</font> changed summoner to " .. self:PrettySummoners(tostring(e:GetSpellData(SUMMONER_2).name):lower()) ..".", e)
			end
			if self.summonerSpells[e.charName]["SummOne"].name ~= e:GetSpellData(SUMMONER_1).name and GetInGameTimer() > 60  then
				self.summonerSpells[e.charName]["SummOne"].summChanged = GetInGameTimer()
				self.summonerSpells[e.charName]["SummOne"].name = e:GetSpellData(SUMMONER_1).name
				self:SummonerTwoPrint("<font color=\"#FFFFFF\">" .. e.charName .. "</font> changed summoner to " .. self:PrettySummoners(tostring(e:GetSpellData(SUMMONER_1).name):lower()) ..".", e)
			end
			
			if (e:GetSpellData(SUMMONER_2).cd - 0.5 < e:GetSpellData(SUMMONER_2).currentCd) and e:GetSpellData(SUMMONER_2).currentCd > 0 then
				local cDM = os.date("!%X",GetInGameTimer() + e:GetSpellData(SUMMONER_2).cd)
				self:SummonerTwoPrint("<font color=\"#FFFFFF\">" .. e.charName .. "</font> used " .. self:PrettySummoners(tostring(e:GetSpellData(SUMMONER_2).name):lower()) ..", off cd at <font color=\"#00FF00\">" .. cDM .." min.</font>", e)
			end
			if (e:GetSpellData(SUMMONER_1).cd - 0.5 < e:GetSpellData(SUMMONER_1).currentCd) and e:GetSpellData(SUMMONER_1).currentCd > 0 then
				local cDM = os.date("!%X",GetInGameTimer() + e:GetSpellData(SUMMONER_1).cd)
				self:SummonerOnePrint("<font color=\"#FFFFFF\">" .. e.charName .. "</font> used " .. self:PrettySummoners(tostring(e:GetSpellData(SUMMONER_1).name):lower()) ..", off cd at <font color=\"#00FF00\">" .. cDM .." min.</font>", e)
			end
		end
	end
end

function MyAwareness:SummonerOnePrint(str, enemy)
	if str ~= self.lastPrintSum1 and self.lastHeroSum1 ~= enemy:GetSpellData(SUMMONER_2).name and self.lastHeroName1 ~= enemy.charName and self.lm2 ~= str and (self.summonerSpells[enemy.charName]["SummOne"].lastPrint == 0 or self.summonerSpells[enemy.charName]["SummOne"].lastPrint <= GetInGameTimer() - 30) then
		self.summonerSpells[enemy.charName]["SummOne"].lastPrint = GetInGameTimer()
		self.lm2 = str
		PrintChat(str)
		lastPrintSum1 = str
		lastHeroSum1 = enemy:GetSpellData(SUMMONER_1).name
		lastHeroName1 = enemy.charName
	end
end

function MyAwareness:SummonerTwoPrint(str, enemy)
   if str ~= self.lastPrintSum2 and self.lastHeroSum2 ~= enemy:GetSpellData(SUMMONER_1).name and self.lastHeroName2 ~= enemy.charName and self.lm1 ~= str and (self.summonerSpells[enemy.charName]["SummTwo"].lastPrint == 0 or self.summonerSpells[enemy.charName]["SummTwo"].lastPrint <= GetInGameTimer() - 30) then
		self.summonerSpells[enemy.charName]["SummTwo"].lastPrint = GetInGameTimer()
		self.lm1 = str
		PrintChat(str)
		lastPrintSum2 = str
		lastHeroSum2 = enemy:GetSpellData(SUMMONER_2).name
		lastHeroName2 = enemy.charName
	end
end

function MyAwareness:PrettySummoners(str)
	if str == "summonerbarrier" then
		return "Barrier"
	elseif str == "summonerdot" then
		return "Ignite" 
	elseif str == "summonerhaste" then
		return "Ghost"
	elseif str == "itemsmiteaoe" then
		return "Smite"
	elseif str == "s5_summonersmiteduel" then
		return "Smite"
	elseif str == "s5_summonersmiteplayerganker" then
		return "Smite"
	elseif str == "s5_summonersmitequick" then
		return "Smite"
	elseif str == "snowballfollowupcast" then
		return "Dash"
	elseif str == "summonerboost" then
		return "Cleanse"
	elseif str == "summonerexhaust" then
		return "Exhaust"
	elseif str == "summonerflash" then
		return "Flash"
	elseif str == "summonerheal" then
		return "Heal"
	elseif str == "summonermana" then
		return "Clarity"
	elseif str == "summonersnowball" then
		return "Mark"
	elseif str == "summonerteleport" then
		return "Teleport"
	elseif str == "summonerclairvoyance" then
		return "Clairvoyance"
	else
		return "Unknown Spell [" .. str .. "]"
	end
end

function MyAwareness:OnDraw_TowerRange()
	for i, tow in ipairs(self.towers) do
		if tow.health >  0 and GetDistanceSqr(tow.pos) <= (tRange + 1000) * (tRange + 1000) then
			DrawCircle(tow.x, tow.y, tow.z, self.tRange, RGB(80, 0, 0))
		end
	end
end

function MyAwareness:OnLoad_TowerRange()
	for i = 1, objManager.iCount, 1 do
		local tow = objManager:getObject(i)
		if tow ~= nil then
			if tow.type == "obj_AI_Turret" and not string.find(tow.name, "TurretShrine") then
				table.insert(self.towers, tow)
			end
		end
	end
end

--[[-----------------------------------------------------
---------------------ITEM MANAGER------------------------
-----------------------------------------------------]]--
--[[
Items:
BilgewaterCutlass
HextechGunblade
ItemTiamatCleave
YoumusBlade

RanduinsOmen
ItemRighteousGlory

ItemMercurial
QuicksilverSash

ItemCrystalFlask
FlaskOfCrystalWater

ElixirOfIron
ElixirOfRuin
ElixirOfSorcery
ElixirOfWrath

ItemGhostWard
TrinketTotemLvl1
TrinketTotemLvl2
SightWard
VisionWard
]]--
class("MyItems")
function MyItems:__init()
	_G.zeroBundle.Menu:addSubMenu(">> Item Settings <<", "Items")
		_G.zeroBundle.Menu.Items:addParam("tiamat", "Use Tiamat", SCRIPT_PARAM_ONOFF, true)
		_G.zeroBundle.Menu.Items:addParam("titanic", "Use Titanic Hydra", SCRIPT_PARAM_ONOFF, true)
		_G.zeroBundle.Menu.Items:addParam("ravenous", "Use Ravenous Hydra", SCRIPT_PARAM_ONOFF, true)
end

function MyItems:GetItemSlot(name)
	for i = 6, 12 do
		item = myHero:GetSpellData(i)
		if item.name:lower() == name:lower() then
			return i
		end
	end
end

function MyItems:GetWard()
	local ghostWard = self:GetItemSlot("ItemGhostWard")
	if ghostWard and myHero:CanUseSpell(ghostWard) == READY then
		return ghostWard
	end
	
	local trinketOne = self:GetItemSlot("TrinketTotemLvl1")
	if trinketOne and myHero:CanUseSpell(trinketOne) == READY then
		return 12
	end
	
	local trinketTwo = self:GetItemSlot("TrinketTotemLvl2")
	if trinketTwo and myHero:CanUseSpell(trinketTwo) == READY then
		return 12
	end
	
	local sightWard = self:GetItemSlot("SightWard")
	if sightWard and myHero:CanUseSpell(sightWard) == READY then
		return sightWard
	end
	
	local visionWard = self:GetItemSlot("VisionWard")
	if visionWard and myHero:CanUseSpell(visionWard) == READY then
		return visionWard
	end
	
	return nil
end


--[[-----------------------------------------------------
-------------------ORB WALK SELECTOR---------------------
-----------------------------------------------------]]--

class("OrbWalkManager")
function OrbWalkManager:__init()
	self.sacDetected = false
	self.sacPDetected = false
	self.sxDetected = false
	self.pewDetected = false
	
	if _G.Reborn_Loaded or _G.Reborn_Initialised or _G.AutoCarry ~= nil then
		PrettyPrint("Detected SAC:R.", false)
		DelayAction(function()
			self.sacDetected = true
		end, 5)
	elseif SAC then
		PrettyPrint("Detected SAC:P.", false)
		DelayAction(function()
			self.sacPDetected = true
		end, 5)
	elseif _Pewalk then
		PrettyPrint("Detected Pewalk.", false)
		DelayAction(function()
			self.pewDetected = true
		end, 5)
	elseif FileExist(LIB_PATH .. "SxOrbWalk.lua") then
		PrettyPrint("Detected SxOrbWalk.", false)
		require("SxOrbWalk")
		DelayAction(function()
			self.sxDetected = true
		end, 5)
	else
		PrettyPrint("No orb walk detected!", false)
	end
end

function OrbWalkManager:Mode()
	if self.sacDetected then
		if _G.AutoCarry.Keys.AutoCarry then
			return "Combo"
		elseif _G.AutoCarry.Keys.MixedMode then
			return "Harass"
		elseif _G.AutoCarry.Keys.LaneClear then
			return "LaneClear"
		elseif _G.AutoCarry.Keys.LastHit then
			return "LastHit"
		end
	end
end

function OrbWalkManager:ResetAA()
	if self.sacDetected then
		_G.AutoCarry.Orbwalker:ResetAttackTimer()
	elseif self.sxDetected then
		_G.SxOrb:ResetAA()
	end
end

function OrbWalkManager:DisableAA()
	if self.sacDetected then
		_G.AutoCarry.MyHero:AttacksEnabled(false)
	elseif self.pewDetected then
		_Pewalk.AllowAttack(false)
	elseif self.sxDetected then
		_G.SxOrb:DisableAttacks()
	end
end

function OrbWalkManager:EnableAA()
	if self.sacDetected then
		_G.AutoCarry.MyHero:AttacksEnabled(true)
	elseif self.pewDetected then
		_Pewalk.AllowAttack(true)
	elseif self.sxDetected then
		_G.SxOrb:EnableAttacks()
	end
end

--[[-----------------------------------------------------
--------------------TARGET SELECTOR----------------------
-----------------------------------------------------]]--
class("MyPrediction")
function MyPrediction:__init()
	if FileExist(LIB_PATH..'TRPrediction.lua') then
		require('TRPrediction')
		if TRPrediction then
			TP = TRPrediction()
		end
	end
	
	
	require "VPrediction"
	VP = VPrediction()
	
	self.TRskillStore = {
		["Q"] = nil,
		["W"] = nil,
		["E"] = nil,
		["R"] = nil
	}
	
	self.skillStore = {
		["Q"] = {
			type = nil,
			delay = nil,
			range = nil,
			width = nil,
			speed = nil,
			col = false
		},
		["W"] = {
			type = nil,
			delay = nil,
			range = nil,
			width = nil,
			speed = nil,
			col = false
		},
		["E"] = {
			type = nil,
			delay = nil,
			range = nil,
			width = nil,
			speed = nil,
			col = false
		},
		["R"] = {
			type = nil,
			delay = nil,
			range = nil,
			width = nil,
			speed = nil,
			col = false
		}
	}
	
	self.TR = nil
end

function MyPrediction:AddQ(t, d, r, w, s, c)
	self.TQ = TR_BindSS({type = t, delay = d, range = r, width = w, speed = s, allowedCollisionCount = c})
end

function PredictQ(t, minHC)
	if t and minHC and self.TQ and self.TP then
		local CastPosition, HitChance= self.TP:GetPrediction(self.TQ, t, myHero)
		if CastPosition and (Hitchance and HitChance > minHC) then
			return CastPosition
		end
	end
	return nil
end

function MyPrediction:AddW(t, d, r, w, s, c)
	self.TW = TR_BindSS({type = t, delay = d, range = r, width = w, speed = s, allowedCollisionCount = c})
end

function PredictW(t, minHC)
	if t and minHC and self.TQ and self.TP then
		local CastPosition, HitChance= self.TP:GetPrediction(self.TW, t, myHero)
		if CastPosition and (Hitchance and HitChance > minHC) then
			return CastPosition
		end
	end
	return nil
end

function MyPrediction:AddE(t, d, r, w, s, c)
	self.TE = TR_BindSS({type = t, delay = d, range = r, width = w, speed = s, allowedCollisionCount = c})
end

function PredictE(t, minHC)
	if t and minHC and self.TE and self.TP then
		local CastPosition, HitChance= TP:GetPrediction(self.TE, t, myHero)
		if CastPosition and (Hitchance and HitChance > minHC) then
			return CastPosition
		end
	end
	return nil
end

function MyPrediction:AddR(t, d, r, w, s, c)
	--self.TRskillStore["R"] = TR_BindSS({type = t, delay = d, range = r, width = w, speed = s, allowedCollisionCount = c})
	print("Adding new spell t: " .. t .. ", d: " .. d .. ", r: " .. r .. ", w: " .. w .. ", s: " .. s)
	self.skillStore["R"] = {
			type = t,
			delay = d,
			range = r,
			width = w,
			speed = s,
			col = c
		}
end

function MyPrediction:PredictR(t, minHC)
	if _G.zeroBundle.Menu.Pred.rPred == 1 then
		PrettyPrint("Predicting r using vpred")
		if t and minHC > 0 then
			local CastPosition, HitChance, Position = VP:GetLineCastPosition(t, self.skillStore["R"].delay, self.skillStore["R"].width, self.skillStore["R"].speed, self.skillStore["R"].range, myHero, self.skillStore["R"].col)
			if CastPosition and HitChance >= minHC and GetDistanceSqr(CastPosition) < 1200 * 1200 then
				return CastPosition
			end
		end
	elseif _G.zeroBundle.Menu.Pred.rPred == 2 then
		if t and TP then
			local CastPosition, HitChance, Info = TP:GetPrediction(TR_BindSS({type = 'IsLinear', delay = self.skillStore["R"].delay, range = self.skillStore["R"].range, width = self.skillStore["R"].width, speed = self.skillStore["R"].speed}), t, myHero)
            if self.skillStore["R"].col and not Info then
                return CastPosition, HitChance
            elseif not self.skillStore["R"].col then
                return CastPosition, HitChance
            end
		end
	else
		PrettyPrint("Predicting r using " .. _G.zeroBundle.Menu.Pred.rPred)
	end
	return nil
end

--[[-----------------------------------------------------
--------------------TARGET SELECTOR----------------------
-----------------------------------------------------]]--
--Last Champ Added: Zoe
class("MyTarget")
function MyTarget:__init(champRange, minionRange, jungleRange, dmgType)
	local priorityTable = {
		p5 = {"Alistar", "Amumu", "Blitzcrank", "Braum", "Dr. Mundo", "Garen", "Gnar", "Gragus", "Leona", "Mordekaiser", "Nautilus", "Olaf", "Poppy", "Rammus", "Rek'Sai", "Sejuani", "Shen", "Singed", "Sion", "Skarner", "Tahm Kench", "Taric", "Thresh", "Trundle", "Vi", "Volibear", "Warwick", "Wukong", "Zac"},
		p4 = {"Aatrox", "Camille", "Cho'Gath", "Darius", "Elise", "Galio", "Hecarim", "Illaoi", "Ivern", "Janna", "Jarvan IV", "Kayn", "Kled", "Lee Sin", "Malphite", "Maokai", "Nasus", "Nocturne", "Nunu", "Ornn", "Pantheon", "Rakan", "Renekton", "Shyvana", "Tryndamere", "Udyr", "Urgot", "Vladimir", "Yorick"},
		p3 = {"Akali", "Aurelion Sol", "Bard", "Ekko", "Evelynn", "Fiora", "Fizz", "Irelia", "Jax", "Karthus", "Kassadin", "Lissandra", "Morgana", "Nami", "Rengar", "Riven", "Rumble", "Shaco", "Sona", "Talon", "Teemo", "Twisted Fate", "Xin Zhao"},
		p2 = {"Ahri", "Anivia", "Annie", "Azir", "Brand", "Cassiopeia", "Corki", "Diana", "Fiddlesticks", "Gangplank", "Heimerdinger", "Jayce", "Karma", "Katarina", "Kayle", "Kennen", "Kha'Zix", "LeBlanc", "Lulu", "Lux", "Malzahar", "Nidalee", "Orianna", "Ryze", "Soraka", "Swain", "Syndra", "Taliyah", "Veigar", "Vel'Koz", "Viktor", "Yasuo", "Ziggs", "Zilean", "Zoe", "Zyra"},
		p1 = {"Ashe", "Caitlyn", "Draven", "Ezreal", "Graves", "Jhin", "Jinx", "Kalista", "Kindred", "Kog'Maw", "Lucian", "Master Yi", "Miss Fortune", "Quinn", "Sivir", "Tristana", "Twitch", "Varus", "Vayne", "Xayah", "Xerath", "Zed"} --Top protiorty
	}
	
	--self:Arrange()
	
	self.range = {
		Champion = champRange,
		Minion = minionRange,
		Jungle = jungleRange
	}
	
	self.jungle = minionManager(MINION_JUNGLE, self.range.Jungle, myHero, MINION_SORT_MAXHEALTH_DEC)
	self.minion = minionManager(MINION_ENEMY, self.range.Minion, myHero, MINION_SORT_MAXHEALTH_DEC)
	self.champion = TargetSelector(TARGET_LESS_CAST_PRIORITY, self.range.Champion, dmgType, true)
end

function MyTarget:SetPriority(table, hero, priority)
	for i=1, #table, 1 do
        if hero.charName:find(table[i]) ~= nil then
            TS_SetHeroPriority(priority, hero.charName)
        end
    end
end

function MyTarget:Arrange()
     local priorityOrder = {
		[1] = {1,1,1,1,1},
        [2] = {1,1,2,2,2},
        [3] = {1,1,2,2,3},
        [4] = {1,1,2,3,4},
        [5] = {1,2,3,4,5},
    }
    local enemies = #GetEnemyHeroes()
    if enemies > 0 then
    	for i, enemy in ipairs(GetEnemyHeroes()) do
    	    self:SetPriority(self.priorityTable.p1, enemy, priorityOrder[enemies][1])
    	    self:SetPriority(self.priorityTable.p2, enemy, priorityOrder[enemies][2])
    	    self:SetPriority(self.priorityTable.p3,  enemy, priorityOrder[enemies][3])
    	    self:SetPriority(self.priorityTable.p4,  enemy, priorityOrder[enemies][4])
    	    self:SetPriority(self.priorityTable.p5,  enemy, priorityOrder[enemies][5])
    	end
		PrettyPrint("Target Selection Setup Complete.", false)
    end
end

function MyTarget:Update(mode)
	if mode == "all" then
		self.champion:update()
		self.minion:update()
		self.jungle:update()
	elseif mode == "Combo" then
		self.champion:update()
	end
end

function MyTarget:GetBestChampionSingleTarget(range)
	
end

function MyTarget:GetBestChampionAoETarget(range, width)

end

function MyTarget:ComboTarget()
	return self.champion.target
end

--[[-----------------------------------------------------
-------------------WALL JUMP HANDLER---------------------
-----------------------------------------------------]]--
class("MyWallJump")
function MyWallJump:__init()
	self.active = false
	if _G.zeroBundle.Champion.champData.useWall then
		self.active = true
	end
end

function MyWallJump:OnTick()
	if not self.active then return false end
	
	if _G.zeroBundle.Menu.Keys.wallJump or _G.zeroBundle.Menu.Keys.flee then
		for i, sI in pairs(_G.zeroBundle.Champion.wallJumpPoints) do
			s = _G.zeroBundle.Champion.wallJumpPoints[i]
			if s and s.From and s.CastPos then
				pD = GetDistanceSqr(s.From)
				if pD < 300*300 then
					if pD > 250*250 then
						myHero:MoveTo(mousePos.x, mousePos.z)
					elseif pD < 250*250 then
						myHero:MoveTo(s.From.x, s.From.z)
					end
					if pD < 25*25 then
						_G.zeroBundle.Champion:WallJump(s.From, s.CastPos)
						break
					end
				end
			end
		end
	end
end

function MyWallJump:OnDraw()
	if not self.active then return false end
	
	color = ARGB(100, 255, 61, 236)
	if _G.zeroBundle.Menu.Keys.wallJump or _G.zeroBundle.Menu.Keys.flee then
		for i, sI in pairs(_G.zeroBundle.Champion.wallJumpPoints) do
			s = _G.zeroBundle.Champion.wallJumpPoints[i]
			if s and s.From and s.To then
				if GetDistanceSqr(s.From) < 900*900 then
					if OnScreen(s.From.x, s.From.y) then
						DrawCircle(s.From.x, myHero.y, s.From.z, 60, color)
						MyDrawArrow(myHero, s.From, color)
					end
					if OnScreen(s.CastPos.x, s.CastPos.y) then
						DrawCircle(s.CastPos.x, myHero.y, s.CastPos.z, 60, color)
					end
				end
			end
		end
	end
end

--[[-----------------------------------------------------
---------------------EVADE HANDLER-----------------------
-----------------------------------------------------]]--

class("MyEvade")
function MyEvade:__init()
	--[[
	Spell Types: circle, line, cone
	]]--
	self.unitSpells = {
		["Ahri"] = {
			["AhriOrbofDeception"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 1000,
				width = 100,
				danger = true,
				spellType = "line",
				aoe = true,
				speed = 2500,
				delay = 0.25,
				name = "Orb of Deception",
				spell = _Q,
				pretty = "Q",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 2
			},
			["AhriOrbReturn"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 1000,
				width = 100,
				danger = true,
				spellType = "line",
				aoe = true,
				speed = 1000,
				delay = 0.25,
				name = "Orb of Deception",
				spell = _Q,
				pretty = "Q",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 2
			},
			["AhriSeduce"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 1000,
				width = 60,
				danger = true,
				spellType = "line",
				aoe = false,
				speed = 1550,
				delay = 0.25,
				name = "Seduce",
				spell = _E,
				pretty = "E",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 4
			}
		},
		["Amumu"] = {
			["BandageToss"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 1100,
				width = 90,
				danger = true,
				spellType = "line",
				aoe = false,
				speed = 2000,
				delay = 0.25,
				name = "Bandage Toss",
				spell = _Q,
				pretty = "Q",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 4
			},
			["CurseoftheSadMummy"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 0,
				width = 550,
				danger = true,
				spellType = "circle",
				aoe = true,
				speed = math.huge,
				delay = 0.25,
				name = "Curse of the Sad Mummy",
				spell = _R,
				pretty = "R",
				canWall = false,
				canDash = false,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 4
			}
		},
		["Anivia"] = {
			["FlashFrost"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 1100,
				width = 110,
				danger = true,
				spellType = "line",
				aoe = false,
				speed = 850,
				delay = 0.25,
				name = "Flash Frost",
				spell = _Q,
				pretty = "Q",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 3
			}
		},
		["Annie"] = {
			["Disintegrate"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 625,
				width = 0,
				danger = false,
				spellType = "target",
				aoe = false,
				speed = math.huge,
				delay = 0.25,
				name = "Disintegrate",
				spell = _Q,
				pretty = "Q",
				canWall = false,
				canDash = false,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 2
			},
			["InfernalGuardian"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 600,
				width = 250,
				danger = true,
				spellType = "circle",
				aoe = true,
				speed = math.huge,
				delay = 0.25,
				name = "Tibbers",
				spell = _R,
				pretty = "R",
				canWall = false,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 4
			}
		},
		["Ashe"] = {
			["EnchantedCrystalArrow"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = math.huge,
				width = 130,
				danger = true,
				spellType = "line",
				aoe = false,
				speed = 1600,
				delay = 0.25,
				name = "Enchanted Arrow",
				spell = _R,
				pretty = "R",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 4,
				missle = "EnchantedCrystalArrow"
			}
		},
		["AurelionSol"] = {
			["AurelionSolQ"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 1500,
				width = 180,
				danger = true,
				spellType = "line",
				aoe = false,
				speed = 850,
				delay = 0.25,
				name = "Q",
				spell = _Q,
				pretty = "Q",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 3,
				missle = "AurelionSolQMissile"
			},
			["AurelionSolR"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 1420,
				width = 120,
				danger = true,
				spellType = "line",
				aoe = true,
				speed = 4500,
				delay = 0.3,
				name = "R",
				spell = _R,
				pretty = "R",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 4,
				missle = "AurelionSolRBeamMissile"
			}
		},
		["Blitzcrank"] = {
			["RocketGrab"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 1050,
				width = 70,
				danger = true,
				spellType = "line",
				aoe = false,
				speed = 1800,
				delay = 0.25,
				name = "Rocket Grab",
				spell = _Q,
				pretty = "Q",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 3,
				missle = "RocketGrabMissile"
			},
			["StaticField"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 0,
				width = 600,
				danger = true,
				spellType = "circle",
				aoe = true,
				speed = math.huge,
				delay = 0.25,
				name = "Static Field",
				spell = _R,
				pretty = "R",
				canWall = false,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 2
			}
		},
		["Brand"] = {
			["BrandQ"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 1100,
				width = 60,
				danger = true,
				spellType = "line",
				aoe = false,
				speed = 1600,
				delay = 0.25,
				name = "Brand Q",
				spell = _Q,
				pretty = "Q",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 3,
				missle = "BrandQMissile"
			},
			["BrandW"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 900,
				width = 260,
				danger = true,
				spellType = "circle",
				aoe = true,
				speed = math.huge,
				delay = 0.25,
				name = "Brand W",
				spell = _W,
				pretty = "W",
				canWall = false,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 2
			}
		},
		["Braum"] = {
			["BraumQ"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 1050,
				width = 60,
				danger = true,
				spellType = "line",
				aoe = false,
				speed = 1700,
				delay = 0.25,
				name = "Braum Q",
				spell = _Q,
				pretty = "Q",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 3,
				missle = "BraumQMissile"
			},
			["BraumRWrapper"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 1200,
				width = 115,
				danger = true,
				spellType = "line",
				aoe = true,
				speed = 1400,
				delay = 0.25,
				name = "Braum W",
				spell = _R,
				pretty = "R",
				canWall = false,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 4
			}
		},
		["Caitlyn"] = {
			["CaitlynPiltoverPeacemaker"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 1300,
				width = 90,
				danger = false,
				spellType = "line",
				aoe = true,
				speed = 2200,
				delay = 0.25,
				name = "Caitlyn Q",
				spell = _Q,
				pretty = "Q",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 2,
				missle = "CaitlynPiltoverPeacemaker"
			}
		},
		["Cassiopeia"] = {
			["CassiopeiaQ"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 850,
				width = 150,
				danger = false,
				spellType = "circle",
				aoe = true,
				speed = math.huge,
				delay = 0.25,
				name = "Cassiopeia Q",
				spell = _Q,
				pretty = "Q",
				canWall = false,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 2,
				missle = "CassiopeiaQ"
			},
			["CassiopeiaR"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 825,
				width = 80,
				danger = true,
				spellType = "cone",
				aoe = true,
				speed = math.huge,
				delay = 0.25,
				name = "Cassiopeia Q",
				spell = _Q,
				pretty = "Q",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 4,
				missle = "CassiopeiaR"
			}
		},
		["Chogath"] = {
			["Rupture"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 950,
				width = 250,
				danger = false,
				spellType = "circle",
				aoe = true,
				speed = math.huge,
				delay = 1.25,
				name = "Rapture",
				spell = _Q,
				pretty = "Q",
				canWall = false,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 3,
				missle = "Rupture"
			}
		},
		["Corki"] = {
			["PhosphorusBomb"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 825,
				width = 250,
				danger = false,
				spellType = "circle",
				aoe = true,
				speed = 1000,
				delay = 0.3,
				name = "Phosphorus Bomb",
				spell = _Q,
				pretty = "Q",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 2,
				missle = "PhosphorusBombMissile"
			},
			["MissileBarrage"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 1300,
				width = 40,
				danger = false,
				spellType = "line",
				aoe = false,
				speed = 2000,
				delay = 0.2,
				name = "Missile Barrage",
				spell = _R,
				pretty = "R",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 2,
				missle = "MissileBarrageMissile"
			},
			["MissileBarrage2"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 1500,
				width = 40,
				danger = false,
				spellType = "line",
				aoe = false,
				speed = 2000,
				delay = 0.2,
				name = "Missile Barrage",
				spell = _R,
				pretty = "R",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 2,
				missle = "MissileBarrageMissile2"
			}
		},
		["Darius"] = {
			["DariusCleave"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 0,
				width = 375,
				danger = false,
				spellType = "circle",
				aoe = true,
				speed = math.huge,
				delay = 0.75,
				name = "Darius Cleave",
				spell = _Q,
				pretty = "Q",
				canWall = false,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 2,
				missle = "DariusCleave"
			},
			["DariusAxeGrabCone"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 550,
				width = 80,
				danger = false,
				spellType = "cone",
				aoe = true,
				speed = math.huge,
				delay = 0.75,
				name = "Darius Axe Grab",
				spell = _R,
				pretty = "R",
				canWall = false,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 4,
				missle = "DariusAxeGrabCone"
			}
		},
		["Darius"] = {
			["DariusCleave"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 0,
				width = 375,
				danger = false,
				spellType = "circle",
				aoe = true,
				speed = math.huge,
				delay = 0.75,
				name = "Darius Cleave",
				spell = _Q,
				pretty = "Q",
				canWall = false,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 2,
				missle = "DariusCleave"
			},
			["DariusAxeGrabCone"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 550,
				width = 80,
				danger = false,
				spellType = "cone",
				aoe = true,
				speed = math.huge,
				delay = 0.75,
				name = "Darius Axe Grab",
				spell = _R,
				pretty = "R",
				canWall = false,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 4,
				missle = "DariusAxeGrabCone"
			}
		},
		["Diana"] = {
			["DianaArc"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 895,
				width = 195,
				danger = true,
				spellType = "circle",
				aoe = true,
				speed = 1400,
				delay = 0.25,
				name = "Diana Q",
				spell = _Q,
				pretty = "Q",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 3,
				missle = "DianaArcArc"
			},
			["DianaArcArc"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 895,
				width = 195,
				danger = true,
				spellType = "circle",
				aoe = true,
				speed = 1400,
				delay = 0.25,
				name = "Diana Q",
				spell = _Q,
				pretty = "Q",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 3,
				missle = "DianaArcArc"
			}
		},
		["DrMundo"] = {
			["InfectedCleaverMissileCast"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 1050,
				width = 60,
				danger = false,
				spellType = "line",
				aoe = true,
				speed = 2000,
				delay = 0.25,
				name = "Infected Cleaver",
				spell = _Q,
				pretty = "Q",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 3,
				missle = "InfectedCleaverMissile"
			}
		},
		["Draven"] = {
			["DravenDoubleShot"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 1100,
				width = 130,
				danger = false,
				spellType = "line",
				aoe = true,
				speed = 1400,
				delay = 0.25,
				name = "Double Shot",
				spell = _E,
				pretty = "E",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 3,
				missle = "DravenDoubleShotMissile"
			},
			["DravenRCast"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = math.huge,
				width = 160,
				danger = true,
				spellType = "line",
				aoe = true,
				speed = 2000,
				delay = 0.4,
				name = "Draven R",
				spell = _R,
				pretty = "R",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 3,
				missle = "DravenR"
			}
		},
		["Ekko"] = {
			["EkkoQ"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 950,
				width = 60,
				danger = true,
				spellType = "line",
				aoe = true,
				speed = 1650,
				delay = 0.25,
				name = "Ekko Q",
				spell = _Q,
				pretty = "Q",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 3,
				missle = "ekkoqmis"
			},
			["EkkoW"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 3750,
				width = 375,
				danger = true,
				spellType = "circle",
				aoe = true,
				speed = 1650,
				delay = 3.75,
				name = "Ekko W",
				spell = _W,
				pretty = "W",
				canWall = false,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 3,
				missle = "EkkoW"
			},
			["EkkoR"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 1600,
				width = 375,
				danger = true,
				spellType = "circle",
				aoe = true,
				speed = 1650,
				delay = 0.25,
				name = "Ekko R",
				spell = _R,
				pretty = "R",
				canWall = false,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 3,
				missle = "EkkoR"
			}
		},
		["Elise"] = {
			["EliseHumanE"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 1100,
				width = 55,
				danger = true,
				spellType = "line",
				aoe = false,
				speed = 1600,
				delay = 0.25,
				name = "Elise E",
				spell = _E,
				pretty = "E",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 4,
				missle = "EliseHumanE"
			}
		},
		["Evelynn"] = {
			["EvelynnR"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 650,
				width = 350,
				danger = true,
				spellType = "circle",
				aoe = true,
				speed = math.huge,
				delay = 0.25,
				name = "Evelyn R",
				spell = _R,
				pretty = "R",
				canWall = false,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 4,
				missle = "EvelynnR"
			}
		},
		["Ezreal"] = {
			["EzrealMysticShot"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 1200,
				width = 60,
				danger = false,
				spellType = "line",
				aoe = false,
				speed = 2000,
				delay = 0.25,
				name = "Mystic Shot",
				spell = _Q,
				pretty = "Q",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 2,
				missle = "EzrealMysticShotPulseMissile"
			},
			["EzrealEssenceFlux"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 1050,
				width = 80,
				danger = false,
				spellType = "line",
				aoe = true,
				speed = 1600,
				delay = 0.25,
				name = "Essence Flux",
				spell = _W,
				pretty = "W",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 2,
				missle = "EzrealEssenceFluxMissile"
			},
			["EzrealTrueshotBarrage"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = math.huge,
				width = 160,
				danger = false,
				spellType = "line",
				aoe = true,
				speed = 2000,
				delay = 1,
				name = "Trueshot Barrage",
				spell = _R,
				pretty = "R",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 3,
				missle = "EzrealTrueshotBarrage"
			}
		},
		["Fiora"] = {
			["FioraW"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 800,
				width = 70,
				danger = false,
				spellType = "line",
				aoe = true,
				speed = 3200,
				delay = 0.5,
				name = "Fiora W",
				spell = _W,
				pretty = "W",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 3,
				missle = "FioraWMissile"
			}
		},
		["Fizz"] = {
			["FizzR"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 1275,
				width = 110,
				danger = true,
				spellType = "line",
				aoe = true,
				speed = 1300,
				delay = 0.25,
				name = "Fizz R",
				spell = _R,
				pretty = "R",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 3,
				missle = "FizzRMissile"
			}
		},
		["Gallio"] = {
			["GalioResoluteSmite"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 900,
				width = 200,
				danger = false,
				spellType = "circle",
				aoe = false,
				speed = 1300,
				delay = 0.25,
				name = "Resolute Smite",
				spell = _Q,
				pretty = "Q",
				canWall = false,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 2,
				missle = "GalioResoluteSmite"
			},
			["GalioRighteousGust"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 1200,
				width = 120,
				danger = false,
				spellType = "line",
				aoe = true,
				speed = 1200,
				delay = 0.25,
				name = "Righteous Gust",
				spell = _E,
				pretty = "E",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 2,
				missle = "GalioRighteousGust"
			},
			["GalioIdolOfDurand"] = {
				needsDelay = true,
				evadeDelay = 0.25,
				range = 0,
				width = 550,
				danger = true,
				spellType = "circle",
				aoe = true,
				speed = 1200,
				delay = 0.25,
				name = "Idol of Durand",
				spell = _R,
				pretty = "R",
				canWall = false,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				dangerLevel = 4,
				missle = ""
			}
		},
		["Gnar"] = {
			["GnarQ"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 1125,
				width = 60,
				danger = false,
				spellType = "line",
				aoe = true,
				speed = 2500,
				delay = 0.25,
				name = "Gnar Q",
				spell = _Q,
				pretty = "Q",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				missle = "gnarqmissile",
				dangerLevel = 2
			},
			["GnarQReturn"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 2500,
				width = 75,
				danger = false,
				spellType = "line",
				aoe = true,
				speed = 2500,
				delay = 0,
				name = "Gnar Q Return",
				spell = _Q,
				pretty = "Q",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				missle = "GnarQMissileReturn",
				dangerLevel = 2
			},
			["GnarBigQ"] = {
				needsDelay = true,
				evadeDelay = 0.2,
				range = 1150,
				width = 90,
				danger = false,
				spellType = "line",
				aoe = false,
				speed = 2100,
				delay = 0.5,
				name = "Gnar Big Q",
				spell = _Q,
				pretty = "Q",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				missle = "GnarBigQMissile",
				dangerLevel = 2
			},
			["GnarBigW"] = {
				needsDelay = true,
				evadeDelay = 0.25,
				range = 600,
				width = 80,
				danger = false,
				spellType = "line",
				aoe = false,
				speed = math.huge,
				delay = 0.6,
				name = "Gnar Big W",
				spell = _W,
				pretty = "W",
				canWall = false,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				missle = "GnarBigW",
				dangerLevel = 2
			},
			["GnarE"] = {
				needsDelay = false,
				evadeDelay = 0.25,
				range = 475,
				width = 2000,
				danger = false,
				spellType = "circle",
				aoe = true,
				speed = 900,
				delay = 0,
				name = "Gnar E",
				spell = _E,
				pretty = "E",
				canWall = false,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				missle = "GnarE",
				dangerLevel = 2
			},
			["GnarR"] = {
				needsDelay = false,
				evadeDelay = 0.25,
				range = 0,
				width = 500,
				danger = true,
				spellType = "circle",
				aoe = true,
				speed = math.huge,
				delay = 0.25,
				name = "Gnar R",
				spell = _R,
				pretty = "R",
				canWall = false,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				missle = "",
				dangerLevel = 4
			},
		},
		["Gragas"] = {
			["GragasQ"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 1100,
				width = 275,
				danger = false,
				spellType = "circle",
				aoe = true,
				speed = 1300,
				delay = 0.25,
				name = "Gragas Q",
				spell = _Q,
				pretty = "Q",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				missle = "GragasQMissile",
				dangerLevel = 2
			},
			["GragasE"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 950,
				width = 200,
				danger = false,
				spellType = "line",
				aoe = false,
				speed = 1200,
				delay = 0,
				name = "Gragas E",
				spell = _E,
				pretty = "E",
				canWall = false,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				missle = "GragasE",
				dangerLevel = 3
			},
			["GragasR"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 1050,
				width = 375,
				danger = true,
				spellType = "circle",
				aoe = true,
				speed = 1800,
				delay = 0.25,
				name = "Gragas R",
				spell = _R,
				pretty = "R",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				missle = "GragasRBoom",
				dangerLevel = 4
			}
		},
		["Graves"] = {
			["GravesQLineSpell"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 808,
				width = 40,
				danger = false,
				spellType = "line",
				aoe = true,
				speed = 3000,
				delay = 0.25,
				name = "Graves Q",
				spell = _Q,
				pretty = "Q",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				missle = "GravesQLineMis",
				dangerLevel = 2
			},
			["GravesChargeShot"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 1100,
				width = 100,
				danger = true,
				spellType = "line",
				aoe = true,
				speed = 2100,
				delay = 0.25,
				name = "Graves R",
				spell = _R,
				pretty = "R",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				missle = "GravesChargeShot",
				dangerLevel = 4
			}
		},
		["Heimerdinger"] = {
			["Heimerdingerwm"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 1500,
				width = 70,
				danger = false,
				spellType = "line",
				aoe = false,
				speed = 1800,
				delay = 0.25,
				name = "Heimerdinger W",
				spell = _W,
				pretty = "W",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				missle = "HeimerdingerWAttack2",
				dangerLevel = 2
			},
			["HeimerdingerE"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 925,
				width = 100,
				danger = true,
				spellType = "circle",
				aoe = true,
				speed = 1200,
				delay = 0.25,
				name = "Graves R",
				spell = _R,
				pretty = "R",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				missle = "heimerdingerespell",
				dangerLevel = 3
			}
		},
		["Illaoi"] = {
			["IllaoiQ"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 850,
				width = 100,
				danger = true,
				spellType = "line",
				aoe = true,
				speed = math.huge,
				delay = 0.75,
				name = "Illaoi Q",
				spell = _Q,
				pretty = "Q",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				missle = "illaoiemis",
				dangerLevel = 3
			},
			["IllaoiE"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 950,
				width = 50,
				danger = true,
				spellType = "line",
				aoe = false,
				speed = 1900,
				delay = 0.25,
				name = "Illaoi E",
				spell = _E,
				pretty = "E",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				missle = "illaoiemis",
				dangerLevel = 4
			},
			["IllaoiR"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 950,
				width = 450,
				danger = true,
				spellType = "circle",
				aoe = true,
				speed = math.huge,
				delay = 0.5,
				name = "Illaoi R",
				spell = _R,
				pretty = "R",
				canWall = false,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				missle = "",
				dangerLevel = 4
			}
		},
		["Irelia"] = {
			["IreliaTranscendentBlades"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 1200,
				width = 65,
				danger = false,
				spellType = "line",
				aoe = true,
				speed = math.huge,
				delay = 0,
				name = "Irelia R",
				spell = _R,
				pretty = "R",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				missle = "IreliaTranscendentBlades",
				dangerLevel = 2
			}
		},
		["Ivern"] = {
			["IvernQ"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 1100,
				width = 65,
				danger = true,
				spellType = "line",
				aoe = false,
				speed = 1300,
				delay = 0.25,
				name = "Ivern Q",
				spell = _Q,
				pretty = "Q",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				missle = "IvernQ",
				dangerLevel = 3
			}
		},
		["Janna"] = {
			["JannaQ"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 1700,
				width = 120,
				danger = true,
				spellType = "line",
				aoe = true,
				speed = 900,
				delay = 0.25,
				name = "Janna Q",
				spell = _Q,
				pretty = "Q",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				missle = "HowlingGaleSpell",
				dangerLevel = 3,
				dynamicRange = true
			}
		},
		["JarvanIV"] = {
			["JarvanIVDragonStrike"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 770,
				width = 70,
				danger = false,
				spellType = "line",
				aoe = true,
				speed = math.huge,
				delay = 0.25,
				name = "Jarvin Q",
				spell = _Q,
				pretty = "Q",
				canWall = false,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				missle = "",
				dangerLevel = 3
			},
			["JarvanIVEQ"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 880,
				width = 70,
				danger = false,
				spellType = "line",
				aoe = true,
				speed = 1450,
				delay = 0.25,
				name = "Jarvin E",
				spell = _E,
				pretty = "E",
				canWall = false,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				missle = "JarvanIVDemacianStandard",
				dangerLevel = 3
			}
		},
		["Jayce"] = {
			["jayceshockblast"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 1300,
				width = 70,
				danger = false,
				spellType = "line",
				aoe = false,
				speed = 1450,
				delay = 0.25,
				name = "Jayce Q",
				spell = _Q,
				pretty = "Q",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				missle = "JayceShockBlastMis",
				dangerLevel = 2
			},
			["JayceQAccel"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 1300,
				width = 70,
				danger = false,
				spellType = "line",
				aoe = false,
				speed = 2350,
				delay = 0.25,
				name = "Jayce E",
				spell = _E,
				pretty = "E",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				missle = "JayceShockBlastWallMis",
				dangerLevel = 2
			}
		},
		["Jhin"] = {
			["JhinW"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 2550,
				width = 40,
				danger = true,
				spellType = "line",
				aoe = false,
				speed = 5000,
				delay = 0.75,
				name = "Jhin W",
				spell = _W,
				pretty = "W",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				missle = "JhinWMissile",
				dangerLevel = 3
			},
			["JhinRShot"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 3500,
				width = 80,
				danger = true,
				spellType = "line",
				aoe = false,
				speed = 5000,
				delay = 0.25,
				name = "Jhin R",
				spell = _R,
				pretty = "R",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				missle = "JhinRShotMis",
				extraMissle = "JhinRShotMis4",
				dangerLevel = 3
			}
		},
		["Jinx"] = {
			["JinxW"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 1500,
				width = 60,
				danger = true,
				spellType = "line",
				aoe = false,
				speed = 3300,
				delay = 0.6,
				name = "Jinx W",
				spell = _W,
				pretty = "W",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				missle = "JinxWMissile",
				dangerLevel = 3
			},
			["JinxR"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = math.huge,
				width = 140,
				danger = true,
				spellType = "line",
				aoe = true,
				speed = 1700,
				delay = 0.25,
				name = "Jinx R",
				spell = _R,
				pretty = "R",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				missle = "JinxR",
				dangerLevel = 3
			}
		},
		["Kalista"] = {
			["KalistaMysticShot"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 1200,
				width = 40,
				danger = false,
				spellType = "line",
				aoe = false,
				speed = 1700,
				delay = 0.25,
				name = "Kalista Q",
				spell = _Q,
				pretty = "Q",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				missle = "kalistamysticshotmis",
				dangerLevel = 2
			}
		},
		["Karma"] = {
			["KarmaQ"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 1050,
				width = 60,
				danger = false,
				spellType = "line",
				aoe = false,
				speed = 1700,
				delay = 0.25,
				name = "Karma Q",
				spell = _Q,
				pretty = "Q",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				missle = "KarmaQMissile",
				dangerLevel = 2
			},
			["KarmaQMantra"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 950,
				width = 80,
				danger = false,
				spellType = "line",
				aoe = true,
				speed = 1700,
				delay = 0.25,
				name = "Karma RQ",
				spell = _Q,
				pretty = "Q",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				missle = "KarmaQMissileMantra",
				dangerLevel = 2
			}
		},
		["Karthus"] = {
			["KarthusLayWasteA1"] = {
				needsDelay = true,
				evadeDelay = 0.125,
				range = 875,
				width = 160,
				danger = true,
				spellType = "circle",
				aoe = true,
				speed = math.huge,
				delay = 1.1,
				name = "Lay Waste",
				spell = _Q,
				pretty = "Q",
				canWall = false,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true
			}
		},
		["Kassadin"] = {
			["RiftWalk"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 450,
				width = 270,
				danger = false,
				spellType = "circle",
				aoe = true,
				speed = math.huge,
				delay = 0.25,
				name = "Rift Walk",
				spell = _R,
				pretty = "R",
				canWall = false,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				missle = "RiftWalk",
				dangerLevel = 2
			}
		},
		["Kennen"] = {
			["KennenShurikenHurlMissile1"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 1050,
				width = 50,
				danger = false,
				spellType = "line",
				aoe = false,
				speed = 1700,
				delay = 0.25,
				name = "Kennen Q",
				spell = _Q,
				pretty = "Q",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				missle = "RiftWalk",
				dangerLevel = 2
			}
		},
		["Khazix"] = {
			["KhazixW"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 1025,
				width = 73,
				danger = false,
				spellType = "line",
				aoe = false,
				speed = 1700,
				delay = 0.25,
				name = "Khazix W",
				spell = _W,
				pretty = "W",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				missle = "KhazixWMissile",
				dangerLevel = 3
			},
			["KhazixE"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 600,
				width = 300,
				danger = false,
				spellType = "circle",
				aoe = true,
				speed = 1500,
				delay = 0.25,
				name = "Khazix E",
				spell = _E,
				pretty = "E",
				canWall = false,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				missle = "KhazixE",
				dangerLevel = 2
			}
		},
		["Kled"] = {
			["KledQ"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 800,
				width = 45,
				danger = true,
				spellType = "line",
				aoe = false,
				speed = 1700,
				delay = 0.25,
				name = "Kled Q",
				spell = _Q,
				pretty = "Q",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				missle = "KledQMissile",
				dangerLevel = 3
			},
			["KledE"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 750,
				width = 125,
				danger = true,
				spellType = "line",
				aoe = false,
				speed = 945,
				delay = 0.25,
				name = "Kled E",
				spell = _E,
				pretty = "E",
				canWall = false,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				missle = "",
				dangerLevel = 2
			},
			["KledRiderQ"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 700,
				width = 40,
				danger = false,
				spellType = "line",
				aoe = false,
				speed = 3000,
				delay = 0.25,
				name = "Kled E",
				spell = _E,
				pretty = "E",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				missle = "KledRiderQMissile",
				dangerLevel = 2
			}
		},
		["Kogmaw"] = {
			["KogMawVoidOoze"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 1360,
				width = 120,
				danger = false,
				spellType = "line",
				aoe = false,
				speed = 1400,
				delay = 0.25,
				name = "Kogmaw Q",
				spell = _Q,
				pretty = "Q",
				canWall = true,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				missle = "KogMawVoidOozeMissile",
				dangerLevel = 2
			},
			["KogMawLivingArtillery"] = {
				needsDelay = false,
				evadeDelay = 0,
				range = 1800,
				width = 225,
				danger = true,
				spellType = "circle",
				aoe = true,
				speed = math.huge,
				delay = 1.2,
				name = "Kogmaw R",
				spell = _R,
				pretty = "R",
				canWall = false,
				canDash = true,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true,
				missle = "KogMawLivingArtillery",
				dangerLevel = 3
			}
		},
		["Warwick"] = {
			["WarwickRChannel"] = {
				needsDelay = false,
				evadeDelay = 0.125,
				range = 700,
				danger = true,
				spellType = "target",
				delay = 0.15,
				name = "Warwick R",
				spell = _R,
				pretty = "R",
				canWall = false,
				canDash = false,
				canEvade = true,
				canSpellSheild = true,
				canSheild = true
			}
		}
	}
	
	self.compiledSpells = {}
	i = 0
	_G.zeroBundle.Menu:addSubMenu(">> Evade Settings <<", "Evade")
	for _,e in pairs(GetEnemyHeroes()) do
		if self.unitSpells[e.charName] then
			_G.zeroBundle.Menu.Evade:addParam("info" .. i, e.charName .. " Spells", SCRIPT_PARAM_INFO, "")
			i = i + 1
			sA = 0
			for k, s in pairs(self.unitSpells[e.charName]) do
				if s then
					isDanger = false
					if s.danger then
						isDanger = true
					end
					_G.zeroBundle.Menu.Evade:addParam(e.charName .. s.pretty, "Evade " .. s.name, SCRIPT_PARAM_ONOFF, isDanger)
					sA = sA + 1
				end
			end
			if sA == 0 then
				_G.zeroBundle.Menu.Evade:addParam("info" .. i, "No known spells.", SCRIPT_PARAM_INFO, "")
				i = i + 1
			end
			
			_G.zeroBundle.Menu.Evade:addParam("info" .. i, "", SCRIPT_PARAM_INFO, "")
			i = i + 1
		end
	end
	
	self.activeSpells = {}
end

function MyEvade:GetDirection(s, e)
	return e - s
end

function MyEvade:GetHitBoxRadius(target)
	return GetDistance(target.minBBox, target.maxBBox) / 2
end

function MyEvade:CheckLineCollisionPoint(x1, y1, x2, y2, circlex, circley, circler)
	for n=0, 1, 0.001 do
		local x = x1 + ((x2 - x1) * n)
		local y = y1 + ((y2 - y1) * n)
		local dist = math.sqrt((x - circlex)^2 + (y - circley)^2)
		local point = {x, y}
		if dist <= circler then return {x, y} end
	end
end

function MyEvade:GetPointsFromRect(x1, y1, x2, y2, l1, l2)
	distanceV = {x2 - x1, y2 - y1}
	vlen = math.sqrt(distanceV[1]^2 + distanceV[2]^2)
	normalized = {distanceV[1] / vlen, distanceV[2] / vlen}
	rotated = {-normalized[2], normalized[1]}
	p1 = {x1 - rotated[1] * l1 / 2, y1 - rotated[2] * l1 / 2}
	p2 = {p1[1] + rotated[1] * l1, p1[2] + rotated[2] * l1}
	p3 = {p1[1] + normalized[1] * l2, p1[2] + normalized[2] * l2}
	p4 = {p3[1] + rotated[1] * l1, p3[2] + rotated[2] * l1}
	points = {p1, p2, p3, p4}
	return points
end

function MyEvade:OnDraw()
	for _, o in pairs(self.activeSpells) do
		if o and o.valid then
			break
		end
	end
end

function MyEvade:OnCreateObj(obj)
	if obj and obj.valid and obj.type == "missile" then
		tmpSpell = {
			startPos = obj.spellStart,
			endPos = obj.spellEnd,
			spellName = obj.spellName,
			spellOwner = obj.spellOwner,
			obj = obj
		}
		table.insert(self.activeSpells, tmpSpell)
		print("Adding missile: " .. obj.name)
	end
end

function MyEvade:OnDeleteObj(obj)
	c = 0
	tmpSpell = {
		startPos = obj.spellStart,
		endPos = obj.spellEnd,
		spellName = obj.spellName,
		spellOwner = obj.spellOwner,
		obj = obj
	}
	for _, o in pairs(self.activeSpells) do
		c = c + 1
		if o == tmpSpell then
			break
		end
	end
	if c > 0 then
		table.remove(self.activeSpells, c)
		print("Removing missile: " .. obj.name)
	end
end

function MyEvade:OnProcessSpell(unit, spell)
	if unit and spell and unit.type == myHero.type and unit.team ~= myHero.team then
		
		if self.unitSpells[unit.charName] and self.unitSpells[unit.charName][spell.name] and self.unitSpells[unit.charName][spell.name].danger then
			eS = self.unitSpells[unit.charName][spell.name]
			--Checks for us
			if myHero and not myHero.dead and myHero.health > 0 then
				if eS.spellType == "target" and spell.target and spell.target.networkID == myHero.networkID then
					if _G.zeroBundle.Champion.champData.useSheild and eS.canSheild then
						_G.zeroBundle.Champion:Sheild(spell, eS, unit, myHero)
					end
					if _G.zeroBundle.Champion.champData.useWall and eS.canWall then
						_G.zeroBundle.Champion:Wall(spell, eS, unit, myHero)
					end
				elseif eS.spellType == "circle" then
					if self:WillAoEHit(eS, spell, unit, myHero) == true then
						handled = false
						if eS.canDash and _G.zeroBundle.Champion.champData.useEvade then
							if _G.zeroBundle.Champion:EvadeDash(spell, eS, unit, myHero) then
								handled = true
							end
						end
						if (eS.canSpellSheild or eS.canSheild) and not handled and _G.zeroBundle.Champion.champData.useSheild then
							if _G.zeroBundle.Champion:Sheild(spell, eS, unit, myHero) then
								handled = true
							end
						end
						if not handled and eS.canEvade and _G.zeroBundle.Champion.champData.useEvade then
							if _G.zeroBundle.Champion:Evade(spell, eS, unit, myHero) then
								handled = true
							end
						end
					end
				elseif eS.spellType == "line" then
					if not eS.aoe then
						if self:WillLineHit(eS, spell, unit, myHero) == true then
							handled = false
							if eS.canDash and _G.zeroBundle.Champion.champData.useEvade then
								if _G.zeroBundle.Champion:EvadeDash(spell, eS, unit, myHero) then
									handled = true
								end
							end
							if (eS.canSpellSheild or eS.canSheild) and not handled and _G.zeroBundle.Champion.champData.useSheild then
								if _G.zeroBundle.Champion:Sheild(spell, eS, unit, myHero) then
									handled = true
								end
							end
							if not handled and eS.canEvade and _G.zeroBundle.Champion.champData.useEvade then
								if _G.zeroBundle.Champion:Evade(spell, eS, unit, myHero) then
									handled = true
								end
							end
						end
					else
						if self:WillAoELineHit(eS, spell, unit, myHero) == true then
							handled = false
							if eS.canDash and _G.zeroBundle.Champion.champData.useEvade then
								if _G.zeroBundle.Champion:EvadeDash(spell, eS, unit, myHero) then
									handled = true
								end
							end
							if (eS.canSpellSheild or eS.canSheild) and not handled and _G.zeroBundle.Champion.champData.useSheild then
								if _G.zeroBundle.Champion:Sheild(spell, eS, unit, myHero) then
									handled = true
								end
							end
							if not handled and eS.canEvade and _G.zeroBundle.Champion.champData.useEvade then
								if _G.zeroBundle.Champion:Evade(spell, eS, unit, myHero) then
									handled = true
								end
							end
						end
					end
				elseif eS.spellType == "cone" then
					if self:WillConeHit(eS, spell, unit, myHero) == true then
						handled = false
						if eS.canDash and _G.zeroBundle.Champion.champData.useEvade then
							if _G.zeroBundle.Champion:EvadeDash(spell, eS, unit, myHero) then
								handled = true
							end
						end
						if (eS.canSpellSheild or eS.canSheild) and not handled and _G.zeroBundle.Champion.champData.useSheild then
							if _G.zeroBundle.Champion:Sheild(spell, eS, unit, myHero) then
								handled = true
							end
						end
						if not handled and eS.canEvade and _G.zeroBundle.Champion.champData.useEvade then
							if _G.zeroBundle.Champion:Evade(spell, eS, unit, myHero) then
								handled = true
							end
						end
					end
				end
			end
			--Checks for allys
			if _G.zeroBundle.Champion.champData.useSheild or _G.zeroBundle.Champion.champData.useWall then
				for kF, f in pairs(GetEnemyHeroes()) do
					if f and not f.dead and f.health > 0 then
						if eS.type == "target" and spell.target.networkID == f.networkID then
							if _G.zeroBundle.Champion.champData.useSheild and eS.canSheild then
								_G.zeroBundle.Champion:Sheild(spell, eS, unit, f)
							end
							if _G.zeroBundle.Champion.champData.useWall and eS.canWall then
								_G.zeroBundle.Champion:Wall(spell, eS, unit, f)
							end
						elseif eS.type == "circle" and spell.target.networkID == f.networkID then
							
						end
					end
				end
			end
		else
			if spell and unit and spell.target and spell.target == myHero then
				PrettyPrint("Detected target spell from " .. unit.charName .. " spell: " .. spell.name)
			end
		end
	
	end
end

function MyEvade:WillStillHit(spellInfo, spell, from, target)
	if myHero and not myHero.dead and myHero.health > 0 then
		eS = spellInfo
		if eS.spellType == "target" and spell.target and spell.target.networkID == myHero.networkID then
			if _G.zeroBundle.Champion.champData.useSheild and eS.canSheild then
				_G.zeroBundle.Champion:Sheild(spell, eS, unit, myHero)
			end
			if _G.zeroBundle.Champion.champData.useWall and eS.canWall then
				_G.zeroBundle.Champion:Wall(spell, eS, unit, myHero)
			end
		elseif eS.spellType == "circle" then
			if self:WillAoEHit(eS, spell, unit, myHero) == true then
				handled = false
				if eS.canDash and _G.zeroBundle.Champion.champData.useEvade then
					if _G.zeroBundle.Champion:EvadeDash(spell, eS, unit, myHero) then
						handled = true
					end
				end
				if (eS.canSpellSheild or eS.canSheild) and not handled and _G.zeroBundle.Champion.champData.useSheild then
					if _G.zeroBundle.Champion:Sheild(spell, eS, unit, myHero) then
						handled = true
					end
				end
				if not handled and eS.canEvade and _G.zeroBundle.Champion.champData.useEvade then
					if _G.zeroBundle.Champion:Evade(spell, eS, unit, myHero) then
						handled = true
					end
				end
			end
		elseif eS.spellType == "line" then
			if not eS.aoe then
				if self:WillLineHit(eS, spell, unit, myHero) == true then
					handled = false
					if eS.canDash and _G.zeroBundle.Champion.champData.useEvade then
						if _G.zeroBundle.Champion:EvadeDash(spell, eS, unit, myHero) then
							handled = true
						end
					end
					if (eS.canSpellSheild or eS.canSheild) and not handled and _G.zeroBundle.Champion.champData.useSheild then
						if _G.zeroBundle.Champion:Sheild(spell, eS, unit, myHero) then
							handled = true
						end
					end
					if not handled and eS.canEvade and _G.zeroBundle.Champion.champData.useEvade then
						if _G.zeroBundle.Champion:Evade(spell, eS, unit, myHero) then
							handled = true
						end
					end
				end
			else
				if self:WillAoELineHit(eS, spell, unit, myHero) == true then
					handled = false
					if eS.canDash and _G.zeroBundle.Champion.champData.useEvade then
						if _G.zeroBundle.Champion:EvadeDash(spell, eS, unit, myHero) then
							handled = true
						end
					end
					if (eS.canSpellSheild or eS.canSheild) and not handled and _G.zeroBundle.Champion.champData.useSheild then
						if _G.zeroBundle.Champion:Sheild(spell, eS, unit, myHero) then
							handled = true
						end
					end
					if not handled and eS.canEvade and _G.zeroBundle.Champion.champData.useEvade then
						if _G.zeroBundle.Champion:Evade(spell, eS, unit, myHero) then
							handled = true
						end
					end
				end
			end
		elseif eS.spellType == "cone" then
			if self:WillConeHit(eS, spell, unit, myHero) == true then
				handled = false
				if eS.canDash and _G.zeroBundle.Champion.champData.useEvade then
					if _G.zeroBundle.Champion:EvadeDash(spell, eS, unit, myHero) then
						handled = true
					end
				end
				if (eS.canSpellSheild or eS.canSheild) and not handled and _G.zeroBundle.Champion.champData.useSheild then
					if _G.zeroBundle.Champion:Sheild(spell, eS, unit, myHero) then
						handled = true
					end
				end
				if not handled and eS.canEvade and _G.zeroBundle.Champion.champData.useEvade then
					if _G.zeroBundle.Champion:Evade(spell, eS, unit, myHero) then
						handled = true
					end
				end
			end
		end
	end
end

function MyEvade:WillLineHit(spellInfo, spell, from, target)
	if checkhitlinepoint(from, spell.endPos, spellInfo.width, spellInfo.range, target, target.boundingRadius or 65) then return true end
	return false
end

function MyEvade:WillAoELineHit(spellInfo, spell, from, target)
	if checkhitlinepass(from, spell.endPos, spellInfo.width, spellInfo.range, target, target.boundingRadius or 65) then return true end
	return false
end

function MyEvade:WillConeHit(spellInfo, spell, from, target)
	if checkhitcone(from, spell.endPos, spellInfo.width, spellInfo.range, target, target.boundingRadius or 65) then return true end
	return false
end

function MyEvade:WillAoEHit(spellInfo, spell, from, target)
	if checkhitaoe(from, spell.endPos, spellInfo.width, spellInfo.range, target, target.boundingRadius or 65) then return true end
	return false
end

--[[-----------------------------------------------------
---------------------CHAMP RENGAR------------------------
-----------------------------------------------------]]--

class("ChampRengar")
function ChampRengar:__init()
	
	self.champData = {
		useAutoMode = false,
		useFleeMode = false,
		useProcessSpell = false,
		useApplyBuff = false,
		useRemoveBuff = false,
		useCreateObj = true,
		useDeleteObj = true,
		useEvade = false,
		useEvadeDash = true,
		useSheild = false,
		useWall = false
	}
	
	--Basic Attack Range: 725 in brush or stealth, +1 feroicty
	
	self.trophies = 0
	self.inBush = false
	self.jumping = false
	self.passive = false
	self.invis = false
	
	self.aaRange = myHero.range + myHero.boundingRadius
	
	self.abilityQ = {
		range = 150,
		type = cone,
		speed = math.huge,
		col = false,
		delay = 0.3
	}
	
	self.abilityW = {
		range = 400,
		type = circle,
		speed = math.huge,
		aoe = true,
		col = false,
		delay = 0.5
	}
	
	self.abilityE = {
		range = 975,
		type = 'IsLinear',
		width = 50,
		delay = 0.25,
		speed = math.huge,
		col = true
	}
	
	self.target = MyTarget(1000, 550, 550, DAMAGE_PHYSICAL)
	
	_G.zeroBundle.Menu:addSubMenu(">> Combo Settings <<", "Combo")
		_G.zeroBundle.Menu.Combo:addParam("q", "Use Q", SCRIPT_PARAM_ONOFF, true)
		_G.zeroBundle.Menu.Combo:addParam("qE", "Use Empowered Q", SCRIPT_PARAM_ONOFF, true)
		_G.zeroBundle.Menu.Combo:addParam("w", "Use W", SCRIPT_PARAM_ONOFF, true)
		_G.zeroBundle.Menu.Combo:addParam("wE", "Use Empowered W", SCRIPT_PARAM_ONOFF, true)
		_G.zeroBundle.Menu.Combo:addParam("e", "Use E", SCRIPT_PARAM_ONOFF, true)
		_G.zeroBundle.Menu.Combo:addParam("eE", "Use Empowered E", SCRIPT_PARAM_ONOFF, true)
		_G.zeroBundle.Menu.Combo:addParam("r", "Use R", SCRIPT_PARAM_ONOFF, true)
	
	_G.zeroBundle.Menu:addSubMenu(">> Harass Settings <<", "Harass")
		_G.zeroBundle.Menu.Harass:addParam("q", "Use Q", SCRIPT_PARAM_ONOFF, true)
		_G.zeroBundle.Menu.Harass:addParam("w", "Use W", SCRIPT_PARAM_ONOFF, true)
		_G.zeroBundle.Menu.Harass:addParam("e", "Use E", SCRIPT_PARAM_ONOFF, true)
	
	_G.zeroBundle.Menu:addSubMenu(">> Lane Clear Settings <<", "LaneClear")
		_G.zeroBundle.Menu.LaneClear:addParam("q", "Use Q", SCRIPT_PARAM_ONOFF, true)
		_G.zeroBundle.Menu.LaneClear:addParam("w", "Use W", SCRIPT_PARAM_ONOFF, true)
		_G.zeroBundle.Menu.LaneClear:addParam("e", "Use E", SCRIPT_PARAM_ONOFF, true)
		
	_G.zeroBundle.Menu:addSubMenu(">> Flee Settings <<", "Flee")
		_G.zeroBundle.Menu.Flee:addParam("q", "Use Q", SCRIPT_PARAM_ONOFF, true)
		_G.zeroBundle.Menu.Flee:addParam("w", "Use W", SCRIPT_PARAM_ONOFF, true)
		_G.zeroBundle.Menu.Flee:addParam("e", "Use E", SCRIPT_PARAM_ONOFF, true)
	
end

function ChampRengar:OnCreateObj(object)
	if object and object.valid and object.name then
		if object.name:find("Rengar_Base_P_Buf_Max.troy") then
			self.passive = true
		elseif object.name:find("Rengar_Base_R_Cas.troy") then
			self.invis = true
		elseif GetDistanceSqr(myHero, object) < 1000 * 1000 and object.name:lower():find("rengar") then
			if object.name:lower():find("ring") then
				self.inBush = true
			end
		end
	end
end

function ChampRengar:OnDeleteObj(object)
	if object and object.valid and object.name then
		if object.name:find("Rengar_Base_P_Buf_Max.troy") then
			self.passive = false
		elseif object.name:find("Rengar_Base_R_Cas.troy") then
			self.invis = false
		elseif GetDistanceSqr(myHero, object) < 1000 * 1000 and object.name:lower():find("rengar") then
			if object.name:lower():find("ring") then
				self.inBush = false
			end
		end
	end
end

function ChampRengar:OnDraw()
	local underChampText = {}
	if self.invis or self.inBush then
		DrawText("Ready To Jump", 18, myHero.x, myHero.y, 0xFF0000FF)
	end
	
	
end

function ChampRengar:OnTick()
	
end

--[[-----------------------------------------------------
---------------------CHAMP RENGAR------------------------
-----------------------------------------------------]]--

class("ChampFizz")
function ChampFizz:__init()
	
	self.champData = {
		useAutoMode = false,
		useFleeMode = false,
		useProcessSpell = false,
		useApplyBuff = true,
		useRemoveBuff = true,
		useCreateObj = false,
		useDeleteObj = false,
		useEvade = true,
		useEvadeDash = true,
		useSheild = false,
		useWall = true
	}
	
	self.wallJumpPoints = {
		{From = Vector(7372, 52.565307617188, 5858),  To = Vector(7372, 52.565307617188, 5858), CastPos = Vector(7110, 58.387092590332, 5612)}, 
		{From = Vector(8222, 51.648384094238, 3158),  To = Vector(8222, 51.648384094238, 3158), CastPos = Vector(8372, 51.130004882813, 2908)}, 
		{From = Vector(3674, 50.331886291504, 7058),  To = Vector(3674, 50.331886291504, 7058), CastPos = Vector(3674, 52.459594726563, 6708)}, 
		{From = Vector(3788, 51.77613067627, 7422),  To = Vector(3788, 51.77613067627, 7422), CastPos = Vector(3774, 52,108779907227, 7706)}, 
		{From = Vector(8372, 50.384059906006, 9606),  To = Vector(8372, 50.384059906006, 9606), CastPos = Vector(7923, 53.530361175537, 9351)}, 
		{From = Vector(6650, 53.829689025879, 11766),  To = Vector(6650, 53.829689025879, 11766), CastPos = Vector(6426, 56.47679901123, 12138)}, 
		{From = Vector(1678, 52.838096618652, 8428),  To = Vector(1678, 52.838096618652, 8428), CastPos = Vector(2050, 51.777256011963, 8416)}, 
		{From = Vector(10822, 52.152740478516, 7456),  To = Vector(10822, 52.152740478516, 7456), CastPos = Vector(10894, 51.722988128662, 7192)},
		{From = Vector(11160, 52.205154418945, 7504),  To = Vector(11160, 52.205154418945, 7504), CastPos = Vector(11172, 51.725219726563, 7208)},	
		{From = Vector(6424, 48.527244567871, 5208),  To = Vector(6424, 48.527244567871, 5208), CastPos = Vector(6824, 48.720901489258, 5308)},
		{From = Vector(13172, 54.201187133789, 6508),  To = Vector(13172, 54.201187133789, 6508), CastPos = Vector(12772, 51.666019439697, 6458)}, 
		{From = Vector(11222, 52.210571289063, 7856),  To = Vector(11222, 52.210571289063, 7856), CastPos = Vector(11072, 62.272243499756, 8156)}, 
		{From = Vector(10372, 61.73225402832, 8456),  To = Vector(10372, 61.73225402832, 8456), CastPos = Vector(10772, 63.136688232422, 8456)},
		{From = Vector(4324, 51.543388366699, 6258),  To = Vector(4324, 51.543388366699, 6258), CastPos = Vector(4024, 52.466369628906, 6358)},
		{From = Vector(6488, 56.632884979248, 11192),  To = Vector(6488, 56.632884979248, 11192), CastPos = Vector(66986, 53.771095275879, 10910)},
		{From = Vector(7672, 52.87260055542, 8906),  To = Vector(7672, 52.87260055542, 8906), CastPos = Vector(7822, 52.446697235107, 9306)}

	}
	
	self.isInE = false
	self.bTarget = nil
	
	self.aaRange = myHero.range + myHero.boundingRadius
	
	self.abilityQ = {
		range = 550,
		delay = 0.2
	}
	
	self.abilityE = {
		range = 400,
		width = 330,
		speed = 1200,
		delay = 0.25
	}
		
	self.abilityR = {
		range = 1200,
		type = 'IsLinear',
		width = 125,
		delay = 0.25,
		speed = 1300,
		col = false
	}
	
	self.target = MyTarget(1200, 550, 550, DAMAGE_MAGIC)
	
	_G.zeroBundle.Menu:addSubMenu(">> Combo Settings <<", "Combo")
		_G.zeroBundle.Menu.Combo:addParam("q", "Use Q", SCRIPT_PARAM_ONOFF, true)
		_G.zeroBundle.Menu.Combo:addParam("w", "Use W", SCRIPT_PARAM_ONOFF, true)
		_G.zeroBundle.Menu.Combo:addParam("e", "Use E", SCRIPT_PARAM_ONOFF, true)
		_G.zeroBundle.Menu.Combo:addParam("r", "Use R", SCRIPT_PARAM_ONOFF, true)
	
	_G.zeroBundle.Menu:addSubMenu(">> Harass Settings <<", "Harass")
		_G.zeroBundle.Menu.Harass:addParam("q", "Use Q", SCRIPT_PARAM_ONOFF, false)
		_G.zeroBundle.Menu.Harass:addParam("w", "Use W", SCRIPT_PARAM_ONOFF, true)
		_G.zeroBundle.Menu.Harass:addParam("e", "Use E", SCRIPT_PARAM_ONOFF, false)
	
	_G.zeroBundle.Menu:addSubMenu(">> Lane Clear Settings <<", "LaneClear")
		_G.zeroBundle.Menu.LaneClear:addParam("q", "Use Q", SCRIPT_PARAM_ONOFF, true)
		_G.zeroBundle.Menu.LaneClear:addParam("w", "Use W", SCRIPT_PARAM_ONOFF, true)
		_G.zeroBundle.Menu.LaneClear:addParam("e", "Use E", SCRIPT_PARAM_ONOFF, true)
		
	_G.zeroBundle.Menu:addSubMenu(">> Flee Settings <<", "Flee")
		_G.zeroBundle.Menu.Flee:addParam("q", "Use Q", SCRIPT_PARAM_ONOFF, true)
		_G.zeroBundle.Menu.Flee:addParam("e", "Use E", SCRIPT_PARAM_ONOFF, true)
		
	_G.zeroBundle.Menu:addSubMenu(">> Prediction <<", "Pred")
		_G.zeroBundle.Menu.Pred:addParam("rPred", "R Prediction", SCRIPT_PARAM_LIST, 1, {"VPred", "TRPred", "KPred"})
	
	
	PrettyPrint("Loaded: <b>Fizz - Master of Fish</b>", false)
end

function ChampFizz:KillSteal()
	for _,e in pairs(GetEnemyHeroes()) do
		if e and ValidTarget(e) then
			eD = GetDistanceSqr(e)
			if eD < self.aaRange and spellReady(_W) and self:WDamage(e) > e.health then
				CastSpell(_W)
				myHero:Attack(e)
				return true
			elseif eD < self.abilityQ.range and spellReady(_Q) and self:QDamage(e) > e.health then
				CastSpell(_Q, e)
				return true
			elseif eD < self.abilityE.range and spellReady(_E) and self:EDamage(e) > e.health then
				CastSpell(_E, e.x, e.z)
				return true
			elseif eD < self.abilityR.range and spellReady(_R) and self:RDamage(e) > e.health then
				r = _G.zeroBundle.Prediction:PredictR(target, 1.75)
				if r then
					CastSpell(_R, r.x, r.z)
					return true
				end
			elseif eD < self.abilityQ.range and spellReady(_Q) and spellReady(_W) and self:QDamage(e) + self:WDamage(e) > e.health then
				CastSpell(_W)
				CastSpell(_Q, e)
				return true
			end
		end
	end
end

function ChampFizz:SetupSkills()
	_G.zeroBundle.Prediction:AddR(self.abilityR.type, self.abilityR.delay, self.abilityR.range, self.abilityR.width, self.abilityR.speed, self.abilityR.col)
end

function ChampFizz:Combo()
	target = self.bTarget
	if target and not target.dead and target.health > 0 then
		tD = GetDistanceSqr(target)
		
		if _G.zeroBundle.Menu.Combo.r and tD < self.abilityR.range * self.abilityR.range and spellReady(_R) and _G.zeroBundle.Prediction then
			r = _G.zeroBundle.Prediction:PredictR(target, 1.5)
			if r then
				CastSpell(_R, r.x, r.z)
				if _G.zeroBundle.Menu.Combo.e and tD > self.abilityQ.range * self.abilityQ.range and tD < self.abilityE.range * self.abilityE.range and spellReady(_E) then
					CastSpell(_E, r.x, r.z)
				end
				return true
			end
		end
		
		if _G.zeroBundle.Menu.Combo.w and tD < self.aaRange * self.aaRange and spellReady(_W) then
			CastSpell(_W)
			return true
		end
		
		if _G.zeroBundle.Menu.Combo.q and tD > (self.aaRange * self.aaRange) * 1.25 and tD < self.abilityQ.range * self.abilityQ.range and spellReady(_Q) then
			if _G.zeroBundle.Menu.Combo.w and spellReady(_W) then
				CastSpell(_W)
			end
			CastSpell(_Q, target)
			return true
		elseif _G.zeroBundle.Menu.Combo.e and tD > (self.aaRange * self.aaRange) and tD < self.abilityE.range * self.abilityE.range and spellReady(_E) then
			CastSpell(_E, target.x, target.z)
			return true
		end
	end
end

function ChampFizz:Harass()
	target = self.bTarget
	if target and not target.dead and target.health > 0 then
		tD = GetDistanceSqr(target)
		
		if _G.zeroBundle.Menu.Harass.r and tD < self.abilityR.range * self.abilityR.range and spellReady(_R) and _G.zeroBundle.Prediction then
			r = _G.zeroBundle.Prediction:PredictR(target, 1.5)
			if r then
				CastSpell(_R, r.x, r.z)
				if _G.zeroBundle.Menu.Harass.e and tD > self.abilityQ.range * self.abilityQ.range and tD < self.abilityE.range * self.abilityE.range and spellReady(_E) then
					CastSpell(_E, r.x, r.z)
				end
				return true
			end
		end
		
		if _G.zeroBundle.Menu.Harass.w and tD < self.aaRange * self.aaRange and spellReady(_W) then
			CastSpell(_W)
			return true
		end
		
		if _G.zeroBundle.Menu.Harass.q and tD > (self.aaRange * self.aaRange) * 1.25 and tD < self.abilityQ.range * self.abilityQ.range and spellReady(_Q) then
			if _G.zeroBundle.Menu.Harass.w and spellReady(_W) then
				CastSpell(_W)
			end
			CastSpell(_Q, target)
			return true
		elseif _G.zeroBundle.Menu.Harass.e and tD > (self.aaRange * self.aaRange) and tD < self.abilityE.range * self.abilityE.range and spellReady(_E) then
			CastSpell(_E, target.x, target.z)
			return true
		end
	end
end

function ChampFizz:LaneClear()
	if _G.zeroBundle.Menu.Keys.harassLaneClear then
		self:Harass()
	end
	
	for _,m in pairs(self.target.minion.objects) do
		if m and ValidTarget(m) then
			mR = GetDistanceSqr(m)
			if _G.zeroBundle.Menu.LaneClear.q and mR < self.abilityQ.range and self:QDamage(m) > m.health and mR > self.aaRange * 1.25 then
				CastSpell(_Q, m)
				return true
			elseif _G.zeroBundle.Menu.LaneClear.w and mR <= self.aaRange and self:WDamage(m) > m.health then
				CastSpell(_W)
				myHero:Attack(m)
				return true
			end
		end
	end
end

function ChampFizz:JungleClear()
	
end

function ChampFizz:LastHit()
	
end

function ChampFizz:OnCreateObj(object)
	
end

function ChampFizz:OnDeleteObj(object)
	
end

function ChampFizz:OnApplyBuff(source, unit, buff)
	if source == myHero then
		if buff.name:find("fizze") then
			print("in E")
			self.isInE = true
		end
	end
end

function ChampFizz:OnRemoveBuff(unit, buff)
	if unit and unit.isMe and buff.name == "fizzeicon" then
		self.isInE = false
	end
end

function ChampFizz:OnDraw()
	
end

function ChampFizz:OnTick()
	self.target:Update("Combo")
	self.bTarget = self.target:ComboTarget()
	
	if self.isInE then
		if self.bTarget and ValidTarget(self.bTarget) and GetDistanceSqr(self.bTarget) < self.abilityE.range * self.abilityE.range then
			CastSpell(_E, self.bTarget.x, self.bTarget.z)
		end
	end
end

function ChampFizz:Evade(spell, eS, unit, myHero)
	if spellReady(_E) then
		CastSpell(_E, myHero.x, myHero.z)
		return true
	end
	return false
end

function ChampFizz:EvadeDash(spell, eS, unit, myHero)
	print("Spell: " .. eS.name .. " passed to evade dash handler")
	return false
end

function ChampFizz:WallJump(from, to)
	if spellReady(_E) then
		CastSpell(_E, to.x, to.z)
	end
end

function ChampFizz:GetDamage(t)
	return math.ceil(self:RDamage(t) + self:EDamage(t) + self:WDamage(t) + self:QDamage(t))
end

function ChampFizz:RDamage(t)
	if spellReady(_R) then
		local dmg
		tD = GetDistanceSqr(t)
		
		if tD > 910 * 910 then
			dmg = myHero:GetSpellData(_R).level * 100 + 200 + 1.2 * myHero.ap
		elseif tD < 910 * 910 and tD > 455 * 455 then
			dmg = myHero:GetSpellData(_R).level * 100 + 125 + 0.8 * myHero.ap
		elseif tD < 455 * 455 then
			dmg = myHero:GetSpellData(_R).level * 100 + 50 + 0.6 * myHero.ap
		end
		
		return myHero:CalcMagicDamage(t,dmg)
	else
		return 0
	end
end

function ChampFizz:EDamage(t)
	if spellReady(_E) then
		local dmg = myHero:GetSpellData(_E).level * 50 + 20 + 0.75 * myHero.ap
		return myHero:CalcMagicDamage(t,dmg)
	else
		return 0
	end
end

function ChampFizz:WDamage(t)
	if spellReady(_W) then
		local dmg = myHero:GetSpellData(_W).level * 15 + 10
		return myHero:CalcMagicDamage(t,dmg)
	else
		return 0
	end
end

function ChampFizz:QDamage(t)
	if spellReady(_Q) then
		local dmg = myHero:GetSpellData(_Q).level * 15 - 5 + 0.35 * myHero.ap
		return myHero:CalcMagicDamage(t,dmg)
	else
		return 0
	end
end

--[[-----------------------------------------------------
----------------------CHAMP FIORA------------------------
-----------------------------------------------------]]--
--[[
SE - Left
NE - Top
SW - Down
NW - Right
]]--
class("ChampFiora")
function ChampFiora:__init()
	
	self.champData = {
		useAutoMode = false,
		useFleeMode = false,
		useProcessSpell = false,
		useApplyBuff = true,
		useRemoveBuff = true,
		useCreateObj = true,
		useDeleteObj = false,
		useProcessAttack = true,
		useEvade = true,
		useEvadeDash = true,
		useSheild = false,
		useWall = true
	}
	
	self.wallJumpPoints = {
		{From = Vector(7372, 52.565307617188, 5858),  To = Vector(7372, 52.565307617188, 5858), CastPos = Vector(7110, 58.387092590332, 5612)}, 
		{From = Vector(8222, 51.648384094238, 3158),  To = Vector(8222, 51.648384094238, 3158), CastPos = Vector(8372, 51.130004882813, 2908)}, 
		{From = Vector(3674, 50.331886291504, 7058),  To = Vector(3674, 50.331886291504, 7058), CastPos = Vector(3674, 52.459594726563, 6708)}, 
		{From = Vector(3788, 51.77613067627, 7422),  To = Vector(3788, 51.77613067627, 7422), CastPos = Vector(3774, 52,108779907227, 7706)}, 
		{From = Vector(8372, 50.384059906006, 9606),  To = Vector(8372, 50.384059906006, 9606), CastPos = Vector(7923, 53.530361175537, 9351)}, 
		{From = Vector(6650, 53.829689025879, 11766),  To = Vector(6650, 53.829689025879, 11766), CastPos = Vector(6426, 56.47679901123, 12138)}, 
		{From = Vector(1678, 52.838096618652, 8428),  To = Vector(1678, 52.838096618652, 8428), CastPos = Vector(2050, 51.777256011963, 8416)}, 
		{From = Vector(10822, 52.152740478516, 7456),  To = Vector(10822, 52.152740478516, 7456), CastPos = Vector(10894, 51.722988128662, 7192)},
		{From = Vector(11160, 52.205154418945, 7504),  To = Vector(11160, 52.205154418945, 7504), CastPos = Vector(11172, 51.725219726563, 7208)},	
		{From = Vector(6424, 48.527244567871, 5208),  To = Vector(6424, 48.527244567871, 5208), CastPos = Vector(6824, 48.720901489258, 5308)},
		{From = Vector(13172, 54.201187133789, 6508),  To = Vector(13172, 54.201187133789, 6508), CastPos = Vector(12772, 51.666019439697, 6458)}, 
		{From = Vector(11222, 52.210571289063, 7856),  To = Vector(11222, 52.210571289063, 7856), CastPos = Vector(11072, 62.272243499756, 8156)}, 
		{From = Vector(10372, 61.73225402832, 8456),  To = Vector(10372, 61.73225402832, 8456), CastPos = Vector(10772, 63.136688232422, 8456)},
		{From = Vector(4324, 51.543388366699, 6258),  To = Vector(4324, 51.543388366699, 6258), CastPos = Vector(4024, 52.466369628906, 6358)},
		{From = Vector(6488, 56.632884979248, 11192),  To = Vector(6488, 56.632884979248, 11192), CastPos = Vector(66986, 53.771095275879, 10910)},
		{From = Vector(7672, 52.87260055542, 8906),  To = Vector(7672, 52.87260055542, 8906), CastPos = Vector(7822, 52.446697235107, 9306)}
	}
	
	self.baseStats = {
		{ --1
			ad = 68
		},
		{ --2
			ad = 70.4
		},
		{ --3
			ad = 72.9
		},
		{ --4
			ad = 75.5
		},
		{ --5
			ad = 78.2
		},
		{ --6
			ad = 81
		},
		{ --7
			ad = 84
		},
		{ --8
			ad = 87.1
		},
		{ --9
			ad = 90.2
		},
		{ --10
			ad = 93.5
		},
		{ --11
			ad = 97
		},
		{ --12
			ad = 100.5
		},
		{ --13
			ad = 104.1
		},
		{ --14
			ad = 107.9
		},
		{ --15
			ad = 111.8
		},
		{ --16
			ad = 115.8
		},
		{ --17
			ad = 119.9
		},
		{ --18
			ad = 124.1
		}
	}
	
	self.bTarget = nil
	
	self.aaRange = myHero.range + myHero.boundingRadius
	
	self.abilityQ = {
		range = 500,
		delay = 0.2
	}
	
	self.abilityW = {
		range = 725,
		delay = 0.5,
		width = 70,
		speed = 3200,
		type = 'IsLinear'
	}
		
	self.abilityR = {
		range = 500
	}
	
	self.vitalMarks = {}
	for _,e in pairs(GetEnemyHeroes()) do
		if e then
			self.vitalMarks[e.charName] = { NE = false, NW = false, SE = false, SW = false }
		end
	end
	
	self.target = MyTarget(625, 650, 650, DAMAGE_MAGIC)
	
	_G.zeroBundle.Menu:addSubMenu(">> Combo Settings <<", "Combo")
		_G.zeroBundle.Menu.Combo:addParam("q", "Use Q", SCRIPT_PARAM_ONOFF, true)
		_G.zeroBundle.Menu.Combo:addParam("e", "Use E", SCRIPT_PARAM_ONOFF, true)
		_G.zeroBundle.Menu.Combo:addParam("r", "Use R", SCRIPT_PARAM_ONOFF, true)
	
	_G.zeroBundle.Menu:addSubMenu(">> Harass Settings <<", "Harass")
		_G.zeroBundle.Menu.Harass:addParam("q", "Use Q", SCRIPT_PARAM_ONOFF, false)
		_G.zeroBundle.Menu.Harass:addParam("e", "Use E", SCRIPT_PARAM_ONOFF, false)
	
	_G.zeroBundle.Menu:addSubMenu(">> Lane Clear Settings <<", "LaneClear")
		_G.zeroBundle.Menu.LaneClear:addParam("q", "Use Q", SCRIPT_PARAM_ONOFF, true)
		_G.zeroBundle.Menu.LaneClear:addParam("e", "Use E", SCRIPT_PARAM_ONOFF, true)
		
	_G.zeroBundle.Menu:addSubMenu(">> Flee Settings <<", "Flee")
		_G.zeroBundle.Menu.Flee:addParam("q", "Use Q", SCRIPT_PARAM_ONOFF, true)
		
	_G.zeroBundle.Menu:addSubMenu(">> Prediction <<", "Pred")
		_G.zeroBundle.Menu.Pred:addParam("wPred", "W Prediction", SCRIPT_PARAM_LIST, 1, {"VPred", "TRPred", "KPred"})
	
	
	PrettyPrint("Loaded: <b>Fiora - Duel Me Bitch</b>", false)
end

function ChampFiora:DrawVital(t)
	if t then
		nO = self:GetVitalOffset(t)
		if nO then
			newX = t.pos.x + nO.x
			newZ = t.pos.z + nO.z
			DrawCircle3D(newX, t.pos.y, newZ, 70, 1, RGB(102,204,255))
		end
	end
end

function ChampFiora:KillSteal()
	--[[
	for _,e in pairs(GetEnemyHeroes()) do
		if e and ValidTarget(e) then
			eD = GetDistanceSqr(e)
			if eD < self.aaRange and spellReady(_E) and self:EDamage(e) > e.health then
				CastSpell(_E, e.x, e.z)
				myHero:Attack(e)
				return true
			elseif eD < self.abilityQ.range and spellReady(_Q) and self:QDamage(e) > e.health then
				CastSpell(_Q, e.z, e.z)
				return true
			end
		end
	end
	]]--
end

function ChampFiora:SetupSkills()
	--_G.zeroBundle.Prediction:AddR(self.abilityR.type, self.abilityR.delay, self.abilityR.range, self.abilityR.width, self.abilityR.speed, self.abilityR.col)
end

function ChampFiora:Combo()
	target = self.bTarget
	if target and not target.dead and target.health > 0 and ValidTarget(target) then
		tD = GetDistanceSqr(target)
		
		if _G.zeroBundle.Menu.Combo.r and tD < self.abilityR.range * self.abilityR.range and spellReady(_R) and target.health < self:RDamage(target) and not self:TargetHasVital(target) then
			CastSpell(_R, target)
			return true
		end
		
		if _G.zeroBundle.Menu.Combo.q and tD < self.abilityQ.range * self.abilityQ.range and spellReady(_Q) and self:TargetHasVital(target) then
			vO = self:GetVitalOffset(target)
			if vO then
				newX = target.x + vO.x
				newZ = target.z + vO.z
				CastSpell(_Q, newX, newZ)
				return true
			end
		end
		
		if _G.zeroBundle.Menu.Combo.q and tD > self.aaRange * self.aaRange and spellReady(_Q) and not spellReady(_E) and not self:TargetHasVital(target) then
			CastSpell(_Q, target.x, target.z)
			return true
		end
	end
end

function ChampFiora:GetVitalOffset(t)
	if self.vitalMarks[t.charName].NE == true then
		return {x = 0, z = 85 }
	elseif self.vitalMarks[t.charName].NW == true then
		return {x = 85, z = 0 }
	elseif self.vitalMarks[t.charName].SE == true then
		return {x = -85, z = 0 }
	elseif self.vitalMarks[t.charName].SW == true then
		return {x = 0, z = -85 }
	end
end

function ChampFiora:Harass()
	target = self.bTarget
	if target and not target.dead and target.health > 0 and ValidTarget(target) then
		
	end
end

function ChampFiora:KiteWithTargetVitals(t)
	
end

function ChampFiora:LaneClear()
	if _G.zeroBundle.Menu.Keys.harassLaneClear then
		self:Harass()
	end
	
	for _,m in pairs(self.target.minion.objects) do
		if m and ValidTarget(m) then
			mR = GetDistanceSqr(m)
			if _G.zeroBundle.Menu.LaneClear.q and mR < self.abilityQ.range and self:QDamage(m) > m.health and mR > self.aaRange * 1.25 then
				CastSpell(_Q, m.x, m.z)
				return true
			elseif _G.zeroBundle.Menu.LaneClear.e and mR <= self.aaRange and self:EDamage(m) > m.health then
				CastSpell(_E)
				myHero:Attack(m)
				return true
			end
		end
	end
end

function ChampFiora:JungleClear()
	
end

function ChampFiora:LastHit()
	
end

function ChampFiora:TargetHasVital(t)
	if self.vitalMarks[target.charName].NE or self.vitalMarks[target.charName].NW or self.vitalMarks[target.charName].SE or self.vitalMarks[target.charName].SW then
		return true
	end
	return false
end

function ChampFiora:OnCreateObj(object)
	on = object.name
	if object and object.valid and on:find("Fiora_Base_Passive") then
		if object.spellOwner then
			print("Owner: " .. object.spellOwner.charName)
		end
		if object.spellName then
			print("Name: " .. object.spellName)
		end
		closest = nil
		closestDist = nil
		for _,e in pairs(GetEnemyHeroes()) do
			eD = GetDistanceSqr(e, object.pos)
			if eD < 100 then
				if closest == nil then
					closest = e
					closestDist = eD
				elseif eD < closestDist then
					closest = e
					closestDist = eD
				end
			end
		end
		if closest then
			print("Found on: " .. closest.charName)
			if on:find("NE") then
				self.vitalMarks[closest.charName].NE = true
				self.vitalMarks[closest.charName].NW = false
				self.vitalMarks[closest.charName].SE = false
				self.vitalMarks[closest.charName].SW = false
				print("Found Vital: NE")
			end
			if on:find("NW") then
				self.vitalMarks[closest.charName].NW = true
				self.vitalMarks[closest.charName].NE = false
				self.vitalMarks[closest.charName].SE = false
				self.vitalMarks[closest.charName].SW = false
				print("Found Vital: NW")
			end
			if on:find("SE") then
				self.vitalMarks[closest.charName].SE = true
				self.vitalMarks[closest.charName].NW = false
				self.vitalMarks[closest.charName].NE = false
				self.vitalMarks[closest.charName].SW = false
				print("Found Vital: SE")
			end
			if on:find("SW") then
				self.vitalMarks[closest.charName].SW = true
				self.vitalMarks[closest.charName].NW = false
				self.vitalMarks[closest.charName].SE = false
				self.vitalMarks[closest.charName].NE = false
				print("Found Vital: SW")
			end
		end
	end
end

function ChampFiora:OnDeleteObj(object)
	on = object.name
	if object and object.valid and on:find("Fiora_Base_Passive") then
		closest = nil
		closestDist = nil
		for _,e in pairs(GetEnemyHeroes()) do
			eD = GetDistanceSqr(e, object.pos)
			if eD < 100 then
				if closest == nil then
					closest = e
					closestDist = eD
				elseif eD < closestDist then
					closest = e
					closestDist = eD
				end
			end
		end
		if closest then
			if on:find("NE") then
				self.vitalMarks[closest.charName].NE = false
			end
			if on:find("NW") then
				self.vitalMarks[closest.charName].NW = false
			end
			if on:find("SE") then
				self.vitalMarks[closest.charName].SE = false
			end
			if on:find("SW") then
				self.vitalMarks[closest.charName].SW = false
			end
		end
	end
end

function ChampFiora:OnApplyBuff(source, unit, buff)
	
end

function ChampFiora:OnRemoveBuff(unit, buff)
	
end

function ChampFiora:OnDraw()
	for _, e in pairs(GetEnemyHeroes()) do
		if ValidTarget(e) then
			self:DrawVital(e)
		end
	end
end

function ChampFiora:OnTick()
	self.target:Update("Combo")
	self.bTarget = self.target:ComboTarget()
	
	if self.isInE then
		if self.bTarget and ValidTarget(self.bTarget) and GetDistanceSqr(self.bTarget) < self.abilityE.range * self.abilityE.range then
			CastSpell(_E, self.bTarget.x, self.bTarget.z)
		end
	end
end

function ChampFiora:OnProcessAttack(unit, spell)
	if unit == myHero then
		if _G.zeroBundle.OrbWalk:Mode() == "Combo" then
			if spell.name == "FioraBasicAttack" or spell.name == "FioraBasicAttack2" then
				if spellReady(_E) and self.bTarget and ValidTarget(self.bTarget) and GetDistanceSqr(self.bTarget) <= self.aaRange * self.aaRange then
					CastSpell(_E)
					myHero:Attack(self.bTarget)
					return true
				end
			elseif spell.name == "fioraqattack" then
				if self.bTarget and ValidTarget(self.bTarget) and GetDistanceSqr(self.bTarget) <= self.aaRange * self.aaRange then
					myHero:Attack(self.bTarget)
					return true
				end
			elseif spell.name == "FioraEAttack" or spell.name == "FioraEAttack2" then
				--TODO: Proc Tiamat
			end
		end
	else
		if unit and spell and unit.team ~= myHero.team and unit.type == myHero.type and spell.target and spell.target == myHero and spellReady(_W) then
			if spell.name:find("SummonerDot") then
				CastSpell(_W, unit.x, unit.z)
				PrettyPrint("Auto Parrying [Ignite].")
				return true
			end
			--Check AA Buffs (Fizz W, Fiora E, etc
			if spell.name:lower():find("attack") or spell.name:lower():find("crit") and getDmg("AD", myHero, target) >= myHero.health then
				CastSpell(_W, unit.x, unit.z)
				PrettyPrint("Auto Parrying [Killing Blow].")
				return true
			end
		end
	end
end

function ChampFiora:Evade(spell, eS, unit, myHero)
	if spellReady(_W) then
		if self.bTarget and ValidTarget(self.bTarget) and GetDistanceSqr(self.bTarget) <= self.abilityW.range * self.abilityW.range then
			CastSpell(_W, self.bTarget.x, self.bTarget.z)
		else
			CastSpell(_W, myHero.x, myHero.z)
		end
		return true
	end
	return false
end

function ChampFiora:EvadeDash(spell, eS, unit, hero)
	if spellReady(_Q) then
		--_G.zeroBundle.Evade:WillStillHit(es, spell, hero, unit)
		print("Spell: " .. eS.name .. " passed to evade dash handler")
	end
	return false
end

function ChampFiora:WallJump(from, to)
	if spellReady(_E) then
		CastSpell(_E, to.x, to.z)
	end
end

function ChampFiora:GetDamage(t)
	return math.ceil(self:RDamage(t) + self:EDamage(t) + self:WDamage(t) + self:QDamage(t) + self:PassiveDamage(t))
end

function ChampFiora:RDamage(t)
	if spellReady(_R) then
		return self:PassiveDamage(t) * 2
	else
		return 0
	end
end

function ChampFiora:EDamage(t)
	if spellReady(_E) then
		return myHero:CalcDamage(t, getDmg("AD", t, myHero) * 2)
	else
		return 0
	end
end

function ChampFiora:WDamage(t)
	if spellReady(_W) then
		dmg = 0
		if myHero:GetSpellData(_W).level == 1 then
			dmg = 90 + (myHero.ap)
		elseif myHero:GetSpellData(_W).level == 2 then
			dmg = 130 + myHero.ap
		elseif myHero:GetSpellData(_W).level == 3 then
			dmg = 170 + myHero.ap
		elseif myHero:GetSpellData(_W).level == 4 then
			dmg = 210 + myHero.ap
		elseif myHero:GetSpellData(_W).level == 5 then
			dmg = 250 + myHero.ap
		end
		fD = myHero:CalcMagicDamage(t, dmg)
		return fD
	else
		return 0
	end
end

function ChampFiora:QDamage(t)
	if spellReady(_Q) then
		mBAD = self:GetBonusAD()
		dmg = 0
		if myHero:GetSpellData(_Q).level == 1 then
			dmg = 70 + (0.95 * mBAD)
		elseif myHero:GetSpellData(_Q).level == 2 then
			dmg = 80 + (1 * mBAD)
		elseif myHero:GetSpellData(_Q).level == 3 then
			dmg = 90 + (1.05 * mBAD)
		elseif myHero:GetSpellData(_Q).level == 4 then
			dmg = 100 + (1.1 * mBAD)
		elseif myHero:GetSpellData(_Q).level == 5 then
			dmg = 110 + (1.15 * mBAD)
		end
		fD = myHero:CalcDamage(t, dmg)
		return fD
	else
		return 0
	end
end

function ChampFiora:PassiveDamage(t)
	eMHP = t.maxHealth
	mBAD = self:GetBonusAD()
	dmg = eMHP * 0.025
	if mBAD > 900 then
		dmg = dmg + (eMHP * 0.045)
	end
	if mBAD > 800 then
		dmg = dmg + (eMHP * 0.045)
	end
	if mBAD > 700 then
		dmg = dmg + (eMHP * 0.045)
	end
	if mBAD > 600 then
		dmg = dmg + (eMHP * 0.045)
	end
	if mBAD > 500 then
		dmg = dmg + (eMHP * 0.045)
	end
	if mBAD > 400 then
		dmg = dmg + (eMHP * 0.045)
	end
	if mBAD > 300 then
		dmg = dmg + (eMHP * 0.045)
	end
	if mBAD > 200 then
		dmg = dmg + (eMHP * 0.045)
	end
	if mBAD > 100 then
		dmg = dmg + (eMHP * 0.045)
	end
	return myHero:CalcDamage(t, dmg)
end

function ChampFiora:PassiveHeal(t)
	return 25 + (5 * myHero.level)
end

function ChampFiora:GetBonusAD()
	return myHero.damage - self.baseStats[myHero.level].ad
end

--[[-----------------------------------------------------
------------------INTERNAL FUNCTIONS---------------------
-----------------------------------------------------]]--

function GlobalMenu()
	_G.zeroBundle.Menu:addSubMenu(">> Key Settings <<", "Keys")
		_G.zeroBundle.Menu.Keys:addParam("flee", "Flee Key", SCRIPT_PARAM_ONKEYDOWN, false, string.byte("Z"))
		_G.zeroBundle.Menu.Keys:addParam("wallJump", "Wall Jump Key", SCRIPT_PARAM_ONKEYDOWN, false, string.byte("Z"))
		_G.zeroBundle.Menu.Keys:addParam("harassLaneClear", "Harass in Lane Clear Toggle Key", SCRIPT_PARAM_ONKEYTOGGLE, false, string.byte("G"))
		_G.zeroBundle.Menu.Keys:addParam("evade", "Evade Toggle Key", SCRIPT_PARAM_ONKEYTOGGLE, true, string.byte("H"))
		
	_G.zeroBundle.Menu:addSubMenu(">> Draw Settings <<", "Draw")
		_G.zeroBundle.Menu.Draw:addParam("q", "Draw Q", SCRIPT_PARAM_ONOFF, true)
		_G.zeroBundle.Menu.Draw:addParam("w", "Draw W", SCRIPT_PARAM_ONOFF, true)
		_G.zeroBundle.Menu.Draw:addParam("e", "Draw E", SCRIPT_PARAM_ONOFF, true)
		_G.zeroBundle.Menu.Draw:addParam("r", "Draw R", SCRIPT_PARAM_ONOFF, true)
end

local champLoaded = false

function OnLoad()
	_G.zeroBundle.Menu = scriptConfig("--[[ Zer0 ]]--", "ZeroBundle")
	GlobalMenu()
	
	_G.zeroBundle.Aware = MyAwareness()
	
	DelayAction(function()
	
		if myHero.charName == "Rengar" then
			_G.zeroBundle.Champion = ChampRengar()
			champLoaded = true
		elseif myHero.charName == "Fizz" then
			_G.zeroBundle.Champion = ChampFizz()
			champLoaded = true
		elseif myHero.charName == "Fiora" then
			_G.zeroBundle.Champion = ChampFiora()
			champLoaded = true
		end
		
		if champLoaded then
			_G.zeroBundle.OrbWalk = OrbWalkManager()
			_G.zeroBundle.Evade = MyEvade()
			_G.zeroBundle.WallJump = MyWallJump()
			_G.zeroBundle.Prediction = MyPrediction()
			_G.zeroBundle.Champion:SetupSkills()
		end
	
	end, 5)
end

function OnProcessSpell(unit, spell)
	if not champLoaded then return false end
	
	if _G.zeroBundle.Champion and _G.zeroBundle.Champion.champData.useProcessSpell then
		_G.zeroBundle.Champion:OnProcessSpell(unit, spell)
	end
	if _G.zeroBundle.Champion and _G.zeroBundle.Champion.champData.useEvade and _G.zeroBundle.Evade then
		e = _G.zeroBundle.Evade:OnProcessSpell(unit, spell)
		if e ~= nil then
			_G.zeroBundle.Champion:Evade(e)
		end
	end
end

function OnApplyBuff(source, unit, buff)
	if not champLoaded then return false end
	
	if _G.zeroBundle.Champion and _G.zeroBundle.Champion.champData.useApplyBuff then
		_G.zeroBundle.Champion:OnApplyBuff(source, unit, buff)
	end
end

function OnRemoveBuff(unit, buff)
	if not champLoaded then return false end
	
	if _G.zeroBundle.Champion and _G.zeroBundle.Champion.champData.useRemoveBuff then
		_G.zeroBundle.Champion:OnRemoveBuff(source, unit, buff)
	end
end

function OnProcessAttack(unit, spell)
	if not champLoaded then return false end
	if _G.zeroBundle.Champion and _G.zeroBundle.Champion.champData.useProcessAttack then
		_G.zeroBundle.Champion:OnProcessAttack(unit, spell)
	end
end

function OnDeleteObj(object)
	if not champLoaded then return false end
	
	if _G.zeroBundle.Champion and _G.zeroBundle.Champion.champData.useDeleteObj then
		_G.zeroBundle.Champion:OnDeleteObj(source, unit, buff)
	end
	
	if _G.zeroBundle.Champion and _G.zeroBundle.Champion.champData.useEvade and _G.zeroBundle.Evade then
		_G.zeroBundle.Evade:OnDeleteObj(object)
	end
end

function OnCreateObj(object)
	if not champLoaded then return false end
	
	if _G.zeroBundle.Champion and _G.zeroBundle.Champion.champData.useCreateObj then
		_G.zeroBundle.Champion:OnCreateObj(object)
	end
	
	if _G.zeroBundle.Champion and _G.zeroBundle.Champion.champData.useEvade and _G.zeroBundle.Evade then
		_G.zeroBundle.Evade:OnCreateObj(object)
	end
end

function OnDraw()
	if _G.zeroBundle.Aware then _G.zeroBundle.Aware:OnDraw() end
	if not champLoaded then return false end
	if _G.zeroBundle.Champion and _G.zeroBundle.Menu.Draw then
		_G.zeroBundle.Champion:OnDraw()
		if _G.zeroBundle.Champion.bTarget and not _G.zeroBundle.Champion.bTarget.dead and ValidTarget(_G.zeroBundle.Champion.bTarget) then
			DrawCircle3D(_G.zeroBundle.Champion.bTarget.x, _G.zeroBundle.Champion.bTarget.y, _G.zeroBundle.Champion.bTarget.z, 100, 2, ARGB(175, 0, 255, 0), 25)
		end
		
		for i, Target in pairs(GetEnemyHeroes()) do
			if not Target.dead then
				dmg = _G.zeroBundle.Champion:GetDamage(Target)
				if dmg > Target.health then
					DrawCircle3D(Target.x,Target.y,Target.z,75,3,ARGB(255,255,0,0))
				elseif dmg * 1.25 > Target.health then
					DrawCircle3D(Target.x,Target.y,Target.z,75,3,ARGB(255,0,255,0))
				elseif dmg * 1.5 > Target.health then
					DrawCircle3D(Target.x,Target.y,Target.z,75,3,ARGB(255,0,255,255))
				end
			end
		end
		
		if _G.zeroBundle.Menu.Draw.q and spellReady(_Q) and _G.zeroBundle.Champion.abilityQ and _G.zeroBundle.Champion.abilityQ.range then
			DrawCircle3D(myHero.x, myHero.y, myHero.z, _G.zeroBundle.Champion.abilityQ.range, 3, ARGB(255,255,0,0))
		end
		if _G.zeroBundle.Menu.Draw.w and spellReady(_W) and _G.zeroBundle.Champion.abilityW and _G.zeroBundle.Champion.abilityW.range then
			DrawCircle3D(myHero.x, myHero.y, myHero.z, _G.zeroBundle.Champion.abilityW.range, 3, ARGB(255,255,0,0))
		end
		if _G.zeroBundle.Menu.Draw.e and spellReady(_E) and _G.zeroBundle.Champion.abilityE and _G.zeroBundle.Champion.abilityE.range then
			DrawCircle3D(myHero.x, myHero.y, myHero.z, _G.zeroBundle.Champion.abilityE.range, 3, ARGB(255,255,0,0))
		end
		if _G.zeroBundle.Menu.Draw.r and spellReady(_R) and _G.zeroBundle.Champion.abilityR and _G.zeroBundle.Champion.abilityR.range then
			DrawCircle3D(myHero.x, myHero.y, myHero.z, _G.zeroBundle.Champion.abilityR.range, 3, ARGB(255,255,0,0))
		end
	end
	
	if _G.zeroBundle.WallJump then
		_G.zeroBundle.WallJump:OnDraw()
	end
end

function OnTick()
	if _G.zeroBundle.Aware then _G.zeroBundle.Aware:OnTick() end
	if not champLoaded then return false end
	
	if _G.zeroBundle.WallJump then
		_G.zeroBundle.WallJump:OnTick()
	end
	if _G.zeroBundle.Champion then
		_G.zeroBundle.Champion:OnTick()
		_G.zeroBundle.Champion:KillSteal()
	end
	if _G.zeroBundle.OrbWalk then
		if _G.zeroBundle.OrbWalk:Mode() == "Combo" then
			_G.zeroBundle.Champion:Combo()
		elseif _G.zeroBundle.OrbWalk:Mode() == "Harass" then
			_G.zeroBundle.Champion:Harass()
		elseif _G.zeroBundle.OrbWalk:Mode() == "LaneClear" then
			_G.zeroBundle.Champion:LaneClear()
		elseif _G.zeroBundle.OrbWalk:Mode() == "LastHit" then
			_G.zeroBundle.Champion:LastHit()
		end
	end
end