if myHero.charName ~= "Orianna" then return end

if FileExist(LIB_PATH.."FHPrediction.lua") then
	require("FHPrediction") 
else
	print("<font color=\"#FF5733\">[<b><i>One Ball</i></b>]</font> <font color=\"#3393FF\">Please download FH Prediction for this script to work.</font>")
	return
end
--***********************************************--
--[[
SETUP

1) Copy OneBall.lua into your scripts folder
2) Once in game configure orb walker keys
3) Change any relivant settings (Enemy R #, Q usage in Combo, etc)
4) Use Brain.lua + OneBall Orianna
]]--
--***********************************************--
--[[
INFORMATION

Name: OneBall
Champion: Orianna
Predictions: FHPrediction
Orb Walker: Any (Reccomended: SAC:R)
Credits: Spell lists came from not sure who, but thank you.

**This script will not auto-load any orb walker. You must load it manually.**

Combo Skills: Q, W, E, R
Harass Skills: Q, W, E
Lane Clear Skills: Q, W
Jungle Clear Skills: Q, W
Flee Mode: W, E
Kill Secure: Q, W, R

Features:
-Drawing:
--Draw Q range + damage
--Draw W range + damage
--Draw E range + damage
--Draw R range + damage
--Killable / damage HP drawings
--Shows mode in perma show box
--Lower Lag / Regular drawings
--Draw ball location

-Combo Mode:
--1v1 logic
--Smart Q usage
--Auto W when enemy in range
--Auto E for damage
--Auto cast R always or to kill
--Dynamic spell usage logic

-Team Fight Mode:
--Smart Q usage
--Auto W when enemy in range
--Auto E for damage
--Auto cast R always or to kill
--Dynamic spell usage logic

-Harass Mode:
--Smart Q usage
--Auto W when enemy in range
--Auto E for damage
--Dynamic spell usage logic
--Mana usage logic

-Lane Clear Mode:
--Smart Q Usage
--W Usage
--Toggle harass in lane clear (Default: H)
--Mana usage logic

-Jungle Clear Mode:
--Q Usage
--W Usage
--Mana usage logic

-Auto E 
--Auto defensive E on self
--Auto defensive E on allys
--Auto E on engaging allys
--Auto E targeted spells on me
--Auto E SOME skill shots on me
--Auto E tower shots (self and team)
--Auto E large crits
--Auto E ignite

-Kill Secure Mode:
--Q Usage
--W Usage
--R Usage
--Dynamic spell usage as needed using lowest CD's first

-Auto:
--Auto buy starting items (VIP) (Dorans Ring, 2x HP Pots, Yellow Ward)
--Auto interrupt with selectable spells
--Auto harass on toggle key (Default: J)

-Misc:
--Auto block R if no one in range

-Item Usage:
--Potions: Health Potion, Cookie, Hunter's Potion, Refillable Potion, Corrupting Potion

-Summoner Usage:
--Smite
--Ignite

-Custom Targeting:
--Click a unit to select as target
--Target Selector target
--Custom fall back targeting
]]--
--***********************************************--
--[[
CHANGE LOG
v4 [7/11/2017]
-Added team fighting combo menu
-Fixed a bug with W in team fighting
-Added smite
-Added invulnerable checks
-Added custom targeting
-Added friendly engage checks with menu options
-Changed some skill range/width checks
-Changed lane clear Q to now use Q on the best target
-Added ignite

v3 [7/10/2017]
-Removed some debug print
-Auto buy starting items
-Auto interrupt
-Added E tower shots
-Added E crits
-Fixed a bug in unit valid checks
-Adjusted target selector range to 850 from 950
-Fixed a bug in jungle clear
-Added PermaShow
-Added potion usage

v2 [7/8/2017]
-Added Kill Secure
-Added basic defendive E
-Added offensive E
-Tweaked combo logics

v1 [7/7/2017]
-Initial build
]]--
--***********************************************--
--[[
TO DO
-Smarter R, use FH movement pred to predict if they will be in R
-Smarter W, use FH movement pred to prefict if they will be in W
-Combo R options (only use if killable/always/smart)
-Improve lane clear by checking for most units we can hit with Q
-Auto E ball to us if its far away from enemys
-Check if ally is in range of X champs, if so sheild them so we can W or R
-Check E return path to myself and allys for dmg
-Spell block menu
-Add drawing around ball showing number of enemies that would be hit by W and R
-E damage checks to all Allys in combo instead of just self
-Auto hourglass
-Forst Queens
-Auto barrier
-Auto heal
-Auto CC under tower
-Optamize GetDistance checks to GetDistanceSqr
]]--
--***********************************************--
local myMenu = nil
local ballObj = nil
local hasBall = false
local ts = TargetSelector(TARGET_LESS_CAST, 850)
local jungleMinions = minionManager(MINION_JUNGLE, 815, myHero, MINION_SORT_MAXHEALTH_DEC)
local targetMinions = minionManager(MINION_ENEMY, 1100, myHero, MINION_SORT_MAXHEALTH_DEC)
local enemies = GetEnemyHeroes()
local allies = GetAllyHeroes()
local spellExpired, informationTable = nil, {}
local m = nil
local tickHerosInRangeMe, tickHerosInRangeBall240, tickHerosInRangeBall400, target = nil, nil, nil, nil
local showDebug = true
local isRecalling = false
local focusTarget = nil
local lastChampSpell = {}

local scriptVersion = 3

--Add auto update
--Add lib downloader

local skillData = {
	["Q"] = {
		["range"] = 815,
		["speed"] = 1200,
		["delay"] = 0,
		["width"] = 175,
		["damage"] = function(unit) return myHero:CalcMagicDamage(unit, (((myHero:GetSpellData(_Q).level * 30) + 30) + (myHero.ap * 0.5))) end
	},
	["W"] = {
		["width"] = 245,
		["delay"] = 0.25,
		["damage"] = function(unit) return myHero:CalcMagicDamage(unit, (((myHero:GetSpellData(_W).level * 45) + 25) + (myHero.ap * 0.7))) end
	},
	["E"] = {
		["width"] = 80,
		["delay"] = 0.25,
		["speed"] = 1700,
		["range"] = 1095,
		["damage"] = function(unit) return myHero:CalcMagicDamage(unit, (((myHero:GetSpellData(_E).level * 30) + 30) + (myHero.ap * 0.3))) end
	},
	["R"] = {
		["width"] = 380,
		["delay"] = 0.6,
		["damage"] = function(unit) return myHero:CalcMagicDamage(unit, (((myHero:GetSpellData(_R).level * 75) + 75) + (myHero.ap * 0.7))) end
	}
}

local isUnit = {
	['Aatrox']      = {true, spell = _Q,                  range = 1000,  projSpeed = 1200, },
	['Aatrox']      = {true, spell = _E,                  range = 1000,  projSpeed = 1000, },
	['Ahri']        = {true, spell = _E,                  range = 950,   projSpeed = 1500, },
	['Amumu']       = {true, spell = _Q,                  range = 1100,  projSpeed = 2000, },
	['Amumu']       = {true, spell = _R,                  range = 550,   projSpeed = math.huge, },
	['Anivia']      = {true, spell = _Q,                  range = 1075,  projSpeed = 850, },
	['Annie']       = {true, spell = _Q,                  range = 625,   projSpeed = math.huge, },
	['Annie']       = {true, spell = _W,                  range = 625,   projSpeed = math.huge, },
	['Akali']       = {true, spell = _R,                  range = 800,   projSpeed = 2200, },
	['Alistar']     = {true, spell = _W,                  range = 650,   projSpeed = 2000, },
	['Ashe']        = {true, spell = _R,                  range = 20000, projSpeed = 1600, },
	['Azir']        = {true, spell = _R,                  range = 500,   projSpeed = 1600, },
	['Blitzcrank']  = {true, spell = _Q,                  range = 925,   projSpeed = 1800, },
	['Brand']       = {true, spell = _R,                  range = 750,   projSpeed = 780, },
	['Braum']       = {true, spell = _R,                  range = 1250,  projSpeed = 1600, },
	['Caitlyn']     = {true, spell = _R,                  range = 3000,  projSpeed = math.huge, },
	['Cassiopeia']  = {true, spell = _R,                  range = 825,   projSpeed = math.huge, },
	['Chogath']     = {true, spell = _Q,                  range = 950,   projSpeed = math.huge, },
	['Corki']       = {true, spell = _Q,                  range = 825,   projSpeed = 1125, },
	['Diana']       = {true, spell = _R,                  range = 825,   projSpeed = 2000, },
	['Darius']      = {true, spell = _E,                  range = 540,   projSpeed = 1500, },
	['Darius']      = {true, spell = _R,                  range = 480,   projSpeed = math.huge, },
	['Ezrael']      = {true, spell = _R,                  range = 20000, projSpeed = 2000, },
	['Fiora']       = {true, spell = _R,                  range = 400,   projSpeed = math.huge, },
	['Fizz']        = {true, spell = _R,                  range = 1200,  projSpeed = 1200, },
	['Gangplank']   = {true, spell = _Q,                  range = 620,   projSpeed = math.huge, },
	['Gragas']      = {true, spell = _E,                  range = 600,   projSpeed = 2000, },
	['Gragas']      = {true, spell = _R,                  range = 800,   projSpeed = 1300, },
	['Graves']      = {true, spell = _R,                  range = 1100,  projSpeed = 2100, },
	['Hecarim']     = {true, spell = _R,                  range = 1000,  projSpeed = 1200, },
	--['Irelia']      = {true, spell = _Q,                  range = 650,   projSpeed = 2200, },
	['Irelia']      = {true, spell = _E,                  range = 425,   projSpeed = math.huge, },
	['JarvanIV']    = {true, spell = jarvanAddition,      range = 770,   projSpeed = 2000, },
	['Jax']         = {true, spell = _E,                  range = 250,   projSpeed = math.huge, },
	['Jayce']       = {true, spell = 'JayceToTheSkies',   range = 600,   projSpeed = 2000, },
	['Jinx']        = {true, spell = _R,                  range = 20000, projSpeed = 1700, },
	['Kayle']       = {true, spell = _Q,                  range = 600,   projSpeed = math.huge, },
	['Kennen']      = {true, spell = _Q,                  range = 1000,  projSpeed = 1700, },
	['Khazix']      = {true, spell = _E,                  range = 900,   projSpeed = 2000, },
	['Leblanc']     = {true, spell = _W,                  range = 600,   projSpeed = 2000, },
	['LeeSin']      = {true, spell = 'blindmonkqtwo',     range = 1300,  projSpeed = 1800, },
	['Leona']       = {true, spell = _E,                  range = 900,   projSpeed = 2000, },
	['Leona']       = {true, spell = _R,                  range = 1100,  projSpeed = math.huge, },
	['Lulu']        = {true, spell = _Q,                  range = 950,   projSpeed = 1600, },
	['Lux']         = {true, spell = _Q,                  range = 1300,  projSpeed = 1200, },
	['Malphite']    = {true, spell = _R,                  range = 1000,  projSpeed = 1500},
	['Maokai']      = {true, spell = _Q,                  range = 600,   projSpeed = 1200, },
	['MonkeyKing']  = {true, spell = _E,                  range = 650,   projSpeed = 2200, },
	['Morgana']     = {true, spell = _Q,                  range = 1175,  projSpeed = 1200, },
	['Nocturne']    = {true, spell = _R,                  range = 2000,  projSpeed = 500, },
	['Orianna']     = {true, spell = _Q,                  range = 825,   projSpeed = 1200, },
	['Pantheon']    = {true, spell = _W,                  range = 600,   projSpeed = 2000, },
	['Poppy']       = {true, spell = _E,                  range = 525,   projSpeed = 2000, },
	['Renekton']    = {true, spell = _E,                  range = 450,   projSpeed = 2000, },
	['Sejuani']     = {true, spell = _Q,                  range = 650,   projSpeed = 2000, },
	['Shen']        = {true, spell = _E,                  range = 575,   projSpeed = 2000, },
	['Tristana']    = {true, spell = _W,                  range = 900,   projSpeed = 2000, },
	['Tryndamere']  = {true, spell = 'Slash',             range = 650,   projSpeed = 1450, },
	['Twistedfate'] = {true, spell = _W,                  range = 525,   projSpeed = math.huge, },
	['Vayne']       = {true, spell = _E,                  range = 550,   projSpeed = math.huge, },
	['Veigar']      = {true, spell = _R,                  range = 700,   projSpeed = math.huge, },
	['Vi']          = {true, spell = _R,                  range = 600,   projSpeed = 1200, },
	['Xerath']      = {true, spell = _E,                  range = 1000,  projSpeed = 1200, },
	['XinZhao']     = {true, spell = _E,                  range = 650,   projSpeed = 2000, },
	['Zyra']        = {true, spell = _E,                  range = 1175,  projSpeed = 1400, },
	['Swain']       = {true, spell = _W,                  range = 900,  projSpeed = math.huge, },
}

local interruptSpells = {
    ["Katarina"] = {charName = "Katarina", stop = {name = "Death lotus", spellName = "KatarinaR", ult = true }},
	["Nunu"] = {charName = "Nunu", stop = {name = "Absolute Zero", spellName = "AbsoluteZero", ult = true }},
	["Malzahar"] = {charName = "Malzahar", stop = {name = "Nether Grasp", spellName = "AlZaharNetherGrasp", ult = true}},
	["Caitlyn"] = {charName = "Caitlyn", stop = {name = "Ace in the hole", spellName = "CaitlynAceintheHole", ult = true, projectileName = "caitlyn_ult_mis.troy"}},
	["FiddleSticks"] = {charName = "FiddleSticks", stop = {name = "Crowstorm", spellName = "Crowstorm", ult = true}},
	--["Galio"] = {charName = "Galio", stop = {name = "Idole of Durand", spellName = "GalioIdolOfDurand", ult = true}},
	["Janna"] = {charName = "Janna", stop = {name = "Monsoon", spellName = "ReapTheWhirlwind", ult = true}},
	["MissFortune"] = {charName = "MissFortune", stop = {name = "Bullet time", spellName = "MissFortuneBulletTime", ult = true}},
	["MasterYi"] = {charName = "MasterYi", stop = {name = "Meditate", spellName = "Meditate", ult = false}},
	["Pantheon"] = {charName = "Pantheon", stop = {name = "Skyfall", spellName = "PantheonRJump", ult = true}},
	["Shen"] = {charName = "Shen", stop = {name = "Stand united", spellName = "ShenStandUnited", ult = true}},
	--["Urgot"] = {charName = "Urgot", stop = {name = "Position Reverser", spellName = "UrgotSwap2", ult = true}},
	["Warwick"] = {charName = "Warwick", stop = {name = "Infinite Duress", spellName = "InfiniteDuress", ult = true}},
}

local engageList = {
	  ["Vi"] = "ViQ",--R
	  ["Vi"] = "ViR",--R
	  ["Malphite"] = "Landslide",--R UFSlash
	  ["Nocturne"] = "NocturneParanoia",--R
	  ["Zac"] = "ZacE",--E
	  ["MonkeyKing"] = "MonkeyKingNimbus",--R
	  ["MonkeyKing"] = "MonkeyKingSpinToWin",--R
	  ["MonkeyKing"] = "SummonerFlash",--Flash
	  ["Shyvana"] = "ShyvanaTransformCast",--R
	  ["Thresh"] = "threshqleap",--Q2
	  ["Aatrox"] = "AatroxQ",--Q
	  ["Renekton"] = "RenektonSliceAndDice",--E
	  ["Kennen"] = "KennenLightningRush",--E
	  ["Kennen"] = "SummonerFlash",--Flash
	  ["Olaf"] = "OlafRagnarok",--R
	  ["Udyr"] = "UdyrBearStance",--E
	  ["Volibear"] = "VolibearQ",--Q
	  ["Talon"] = "TalonCutthroat",--e?
	  ["JarvanIV"] = "JarvanIVDragonStrike",--Q
	  ["Warwick"] = "InfiniteDuress",--R
	  ["Jax"] = "JaxLeapStrike",--Q
	  ["Yasuo"] = "YasuoRKnockUpComboW",--Q
	  ["Diana"] = "DianaTeleport",
	  ["LeeSin"] = "BlindMonkQTwo",
	  ["Shen"] = "ShenShadowDash",
	  ["Alistar"] = "Headbutt",
	  ["Amumu"] = "BandageToss",
	  ["Urgot"] = "UrgotSwap2",
	  ["Rengar"] = "RengarR",
	}

function PrettyPrint(message, isDebug)
	if isDebug and not showDebug then return end
	if m == message then
		return
	end
	print("<font color=\"#FF5733\">[<b><i>One Ball</i></b>]</font> <font color=\"#3393FF\">" .. message .. "</font>")
	m = message
end

function createMenu()
	myMenu = scriptConfig("--[[ One Ball Ori ]]--", "OneBall")
		
		myMenu:addSubMenu("--[[ Regular Combo ]]--", "Combo")
			myMenu.Combo:addParam("q", "Use Q", SCRIPT_PARAM_ONOFF, true)
			myMenu.Combo:addParam("info2", " ", SCRIPT_PARAM_INFO, "")
			myMenu.Combo:addParam("w", "Use W", SCRIPT_PARAM_ONOFF, true)
			myMenu.Combo:addParam("info2", " ", SCRIPT_PARAM_INFO, "")
			myMenu.Combo:addParam("e", "Use E", SCRIPT_PARAM_ONOFF, true)
			myMenu.Combo:addParam("info2", " ", SCRIPT_PARAM_INFO, "")
			myMenu.Combo:addParam("r", "Use R", SCRIPT_PARAM_ONOFF, true)
			myMenu.Combo:addParam("rEnemys", "Min Champions to R", SCRIPT_PARAM_SLICE, 2, 0, 5, 0)
		
		myMenu:addSubMenu("--[[ Team Fight Combo ]]--", "TeamCombo")
			myMenu.TeamCombo:addParam("q", "Use Q", SCRIPT_PARAM_ONOFF, true)
			myMenu.TeamCombo:addParam("info2", " ", SCRIPT_PARAM_INFO, "")
			myMenu.TeamCombo:addParam("w", "Use W", SCRIPT_PARAM_ONOFF, true)
			myMenu.TeamCombo:addParam("wEnemys", "Min Champions to E", SCRIPT_PARAM_SLICE, 2, 0, 5, 0)
			myMenu.TeamCombo:addParam("info2", " ", SCRIPT_PARAM_INFO, "")
			myMenu.TeamCombo:addParam("e", "Use E", SCRIPT_PARAM_ONOFF, true)
			myMenu.TeamCombo:addParam("eEnemys", "Min Champions to E", SCRIPT_PARAM_SLICE, 2, 0, 5, 0)
			myMenu.TeamCombo:addParam("info2", " ", SCRIPT_PARAM_INFO, "")
			myMenu.TeamCombo:addParam("r", "Use R", SCRIPT_PARAM_ONOFF, true)
			myMenu.TeamCombo:addParam("rEnemys", "Min Champions to R", SCRIPT_PARAM_SLICE, 2, 0, 5, 0)
			
		myMenu:addSubMenu("--[[ Harass ]]--", "Harass")
			myMenu.Harass:addParam("q", "Use Q", SCRIPT_PARAM_ONOFF, true)
			myMenu.Harass:addParam("qMana", "Minimum Mana", SCRIPT_PARAM_SLICE, 25, 0, 100, 0)
			myMenu.Harass:addParam("info2", " ", SCRIPT_PARAM_INFO, "")
			myMenu.Harass:addParam("w", "Use W", SCRIPT_PARAM_ONOFF, true)
			myMenu.Harass:addParam("wMana", "Minimum Mana", SCRIPT_PARAM_SLICE, 25, 0, 100, 0)
			myMenu.Harass:addParam("info2", " ", SCRIPT_PARAM_INFO, "")
			myMenu.Harass:addParam("e", "Use E", SCRIPT_PARAM_ONOFF, true)
			myMenu.Harass:addParam("eMana", "Minimum Mana", SCRIPT_PARAM_SLICE, 25, 0, 100, 0)
			
		myMenu:addSubMenu("--[[ Lane Clear ]]--", "LaneClear")
			myMenu.LaneClear:addParam("q", "Use Q", SCRIPT_PARAM_ONOFF, true)
			myMenu.LaneClear:addParam("qMana", "Minimum Mana", SCRIPT_PARAM_SLICE, 25, 0, 100, 0)
			myMenu.LaneClear:addParam("info2", " ", SCRIPT_PARAM_INFO, "")
			myMenu.LaneClear:addParam("w", "Use W", SCRIPT_PARAM_ONOFF, true)
			myMenu.LaneClear:addParam("wMana", "Minimum Mana", SCRIPT_PARAM_SLICE, 25, 0, 100, 0)
			
		myMenu:addSubMenu("--[[ Jungle Clear ]]--", "JungleClear")
			myMenu.JungleClear:addParam("q", "Use Q", SCRIPT_PARAM_ONOFF, true)
			myMenu.JungleClear:addParam("qMana", "Minimum Mana", SCRIPT_PARAM_SLICE, 25, 0, 100, 0)
			myMenu.JungleClear:addParam("info2", " ", SCRIPT_PARAM_INFO, "")
			myMenu.JungleClear:addParam("w", "Use W", SCRIPT_PARAM_ONOFF, true)
			myMenu.JungleClear:addParam("wMana", "Minimum Mana", SCRIPT_PARAM_SLICE, 25, 0, 100, 0)
			
		myMenu:addSubMenu("--[[ Kill Secure ]]--", "KillSecure")
			myMenu.KillSecure:addParam("q", "Use Q", SCRIPT_PARAM_ONOFF, true)
			myMenu.KillSecure:addParam("w", "Use W", SCRIPT_PARAM_ONOFF, true)
			myMenu.KillSecure:addParam("e", "Use E for Damage", SCRIPT_PARAM_ONOFF, true)
			myMenu.KillSecure:addParam("r", "Use R", SCRIPT_PARAM_ONOFF, true)
			
		myMenu:addSubMenu("--[[ Auto ]]--", "Auto")
			myMenu.Auto:addParam("e", "Use E", SCRIPT_PARAM_ONOFF, true)
			myMenu.Auto:addParam("eSheild", "Attach On Attack", SCRIPT_PARAM_ONOFF, true)
			myMenu.Auto:addParam("info2", " ", SCRIPT_PARAM_INFO, "")
			myMenu.Auto:addParam("r", "Use R", SCRIPT_PARAM_ONOFF, true)
			myMenu.Auto:addParam("rEnemys", "Min Champions to R", SCRIPT_PARAM_SLICE, 2, 0, 5, 0)
			myMenu.Auto:addParam("blockR", "Block R", SCRIPT_PARAM_ONOFF, true)
			myMenu.Auto:addParam("info2", " ", SCRIPT_PARAM_INFO, "")
			myMenu.Auto:addParam("buy", "Auto Buy Starting", SCRIPT_PARAM_ONOFF, true)
			
		myMenu:addSubMenu("--[[ Keys ]]--", "Keys")
			myMenu.Keys:addParam("Flee", "Flee Key", SCRIPT_PARAM_ONKEYDOWN, false, GetKey("G"))
			myMenu.Keys:addParam("Combo", "Combo Key", SCRIPT_PARAM_ONKEYDOWN, false, GetKey(" "))
			myMenu.Keys:addParam("Harass", "Harass Key", SCRIPT_PARAM_ONKEYDOWN, false, GetKey("C"))
			myMenu.Keys:addParam("LaneClear", "Lane Clear Key", SCRIPT_PARAM_ONKEYDOWN, false, GetKey("V"))
			myMenu.Keys:addParam("JungleClear", "Jungle Clear Key", SCRIPT_PARAM_ONKEYDOWN, false, GetKey("V"))
			myMenu.Keys:addParam("info2", " ", SCRIPT_PARAM_INFO, "")
			myMenu.Keys:addParam("harass", "Auto Harass", SCRIPT_PARAM_ONKEYTOGGLE, false, GetKey("J"))
			myMenu.Keys:addParam("harassInLaneClear", "Harass in Lane Clear", SCRIPT_PARAM_ONKEYTOGGLE, false, GetKey("H"))
			
		myMenu:addSubMenu("--[[ Drawing ]]--", "Draw")
			myMenu.Draw:addParam("lowfps", "Low FPS Circles", SCRIPT_PARAM_ONOFF, true)
			myMenu.Draw:addParam("damage", "Draw Damage", SCRIPT_PARAM_ONOFF, true)
			myMenu.Draw:addParam("permashow", "Show Permashow? (Requires Reload)", SCRIPT_PARAM_ONOFF, true)
			myMenu.Draw:addParam("info2", " ", SCRIPT_PARAM_INFO, "")
			myMenu.Draw:addParam("ball", "Draw Ball Location", SCRIPT_PARAM_ONOFF, true)
			myMenu.Draw:addParam("ballColor", "Ball Draw Color", SCRIPT_PARAM_COLOR, {255, 186, 85, 211})
			myMenu.Draw:addParam("info2", " ", SCRIPT_PARAM_INFO, "")
			myMenu.Draw:addParam("info2", "Skill Drawings", SCRIPT_PARAM_INFO, "")
			myMenu.Draw:addParam("q", "Draw Q", SCRIPT_PARAM_ONOFF, true)
			myMenu.Draw:addParam("qColor", "Q Color", SCRIPT_PARAM_COLOR, {255, 186, 85, 211})
			myMenu.Draw:addParam("info2", " ", SCRIPT_PARAM_INFO, "")
			myMenu.Draw:addParam("w", "Draw W", SCRIPT_PARAM_ONOFF, true)
			myMenu.Draw:addParam("wColor", "W Color", SCRIPT_PARAM_COLOR, {255, 186, 85, 211})
			myMenu.Draw:addParam("info2", " ", SCRIPT_PARAM_INFO, "")
			myMenu.Draw:addParam("e", "Draw E", SCRIPT_PARAM_ONOFF, true)
			myMenu.Draw:addParam("eColor", "E Color", SCRIPT_PARAM_COLOR, {255, 186, 85, 211})
			myMenu.Draw:addParam("info2", " ", SCRIPT_PARAM_INFO, "")
			myMenu.Draw:addParam("r", "Draw R", SCRIPT_PARAM_ONOFF, true)
			myMenu.Draw:addParam("rColor", "R Color", SCRIPT_PARAM_COLOR, {255, 186, 85, 211})
			
		myMenu:addSubMenu("--[[ Interrupt ]]--", "Interrupt")
			myMenu.Interrupt:addParam("r", "Use R to Interrupt", SCRIPT_PARAM_ONOFF, true)
			local iSpells = 0
			for q, en in pairs(enemies) do
				if en and interruptSpells[en.charName] ~= nil then
					myMenu.Interrupt:addParam("" .. en.charName, "" .. en.charName, SCRIPT_PARAM_INFO, "")
					myMenu.Interrupt:addParam("spell".. interruptSpells[en.charName].stop.spellName,"".. interruptSpells[en.charName].stop.name, SCRIPT_PARAM_ONOFF, true)
					iSpells = iSpells + 1
				end
			end
			if iSpells == 0 then
				myMenu.Interrupt:addParam("ii", "No supported spells found,", SCRIPT_PARAM_INFO, "")
			end
		
		myMenu:addSubMenu("--[[ Engage ]] --", "Engage")
			local cEngages = 0
			for champion, spell in pairs(engageList) do
				for i, ally in ipairs(GetAllyHeroes()) do
					if ally.charName == champion then
						myMenu.Engage:addParam(champion..spell, champion.." ["..spell.."]", SCRIPT_PARAM_ONOFF, true)
						cEngages = cEngages + 1
					end
				end
			end
			if cEngages == 0 then
				myMenu.Interrupt:addParam("ii", "No supported spells found,", SCRIPT_PARAM_INFO, "")
			end
		
		myMenu:addSubMenu("--[[ Items ]]--", "Items")
			myMenu.Items:addSubMenu("--[[ Potions ]]--", "Potion")
				myMenu.Items.Potion:addParam("use", "Use Potions", SCRIPT_PARAM_ONOFF, true)
				myMenu.Items.Potion:addParam("hp", "HP Percent to Potion", SCRIPT_PARAM_SLICE, 45, 0, 100, 0)
				myMenu.Items.Potion:addParam("info2", " ", SCRIPT_PARAM_INFO, "")
				myMenu.Items.Potion:addParam("healthpot", "Health Potion", SCRIPT_PARAM_ONOFF, true)
				myMenu.Items.Potion:addParam("healthcookie", "Health Cookie", SCRIPT_PARAM_ONOFF, true)
				myMenu.Items.Potion:addParam("hunterspot", "Hunters Potion", SCRIPT_PARAM_ONOFF, true)
				myMenu.Items.Potion:addParam("refillablepot", "Refillable Potion", SCRIPT_PARAM_ONOFF, true)
				myMenu.Items.Potion:addParam("corruptingpot", "Corrupting Potion", SCRIPT_PARAM_ONOFF, true)
		
		myMenu:addSubMenu("--[[ Summoners ]]--", "Summoner")
			myMenu.Summoner:addParam("smite", "Use Smite", SCRIPT_PARAM_ONOFF, true)
			myMenu.Summoner:addParam("ignite", "Use Ignite", SCRIPT_PARAM_ONOFF, true)
			
		myMenu:addSubMenu("--[[ Misc ]]--", "Misc")
			myMenu.Misc:addParam("target", "Use Sticky Targeting", SCRIPT_PARAM_ONOFF, true)
			myMenu.Misc:addParam("targetMode", "Target Mode", SCRIPT_PARAM_LIST, 1, {"Auto", "Least HP", "Most Fed"})
		
		myMenu:addParam("scriptInfo", "OneBall Orianna Ver: " .. scriptVersion, SCRIPT_PARAM_INFO, "")
		
		if myMenu.Draw.permashow then
			myMenu:permaShow("scriptInfo")
			myMenu.Keys:permaShow("Flee")
			myMenu.Keys:permaShow("Combo")
			myMenu.Keys:permaShow("Harass")
			myMenu.Keys:permaShow("LaneClear")
			myMenu.Keys:permaShow("harass")
			myMenu.Keys:permaShow("harassInLaneClear")
		end
end

function OnLoad()
	PrettyPrint("Welcome To OneBall Orianna " .. GetUser() .. " - Version: " .. scriptVersion .. " - By: AZer0", false)
	PrettyPrint("Game Version: " .. GetGameVersion())
	PrettyPrint("This script is still in BETA please let me know any errors you may find.")
	
	LoadSmite()
	igniteSlot = FindSlotByName("summonerdot")
	
	createMenu()
	if myHero.modelName ~= "Orianna" then
		hasBall = false
	end
	ORI_CheckAllyWithBall()
	
	DelayAction(function()
		AutoBuyStarting()
	end, 3)
end

function OnDraw()
	if myHero.dead then return end
	
	DrawSmiteable()
	DrawTarget()
	
	if myMenu.Draw.lowfps then
		if myMenu.Draw.q and spellReady(_Q) then
      		DrawCircle2(myHero.x, myHero.y, myHero.z, 815, ARGB(myMenu.Draw.qColor[1], myMenu.Draw.qColor[2], myMenu.Draw.qColor[3], myMenu.Draw.qColor[4]))
		end
		
		if myMenu.Draw.w and spellReady(_W) and ballObj then
      		DrawCircle2(ballObj.x, ballObj.y, ballObj.z, 250, ARGB(myMenu.Draw.wColor[1], myMenu.Draw.wColor[2], myMenu.Draw.wColor[3], myMenu.Draw.wColor[4]))
		end
		
		if myMenu.Draw.e and spellReady(_E) then
      		DrawCircle2(myHero.x, myHero.y, myHero.z, 1100, ARGB(myMenu.Draw.eColor[1], myMenu.Draw.eColor[2], myMenu.Draw.eColor[3], myMenu.Draw.eColor[4]))
		end
		
		if myMenu.Draw.r and spellReady(_R) and ballObj then
      		DrawCircle2(ballObj.x, ballObj.y, ballObj.z, 400, ARGB(myMenu.Draw.rColor[1], myMenu.Draw.rColor[2], myMenu.Draw.rColor[3], myMenu.Draw.rColor[4]))
		end
		
		if ballObj and myMenu.Draw.ball then
			DrawCircle2(ballObj.x, ballObj.y, ballObj.z, 80, ARGB(myMenu.Draw.ballColor[1], myMenu.Draw.ballColor[2], myMenu.Draw.ballColor[3], myMenu.Draw.ballColor[4]))
		end
	elseif myMenu.Draw.lowfps == false then
		if myMenu.Draw.q and spellReady(_Q) then
      		DrawCircle(myHero.x, myHero.y, myHero.z, 815, ARGB(myMenu.Draw.qColor[1], myMenu.Draw.qColor[2], myMenu.Draw.qColor[3], myMenu.Draw.qColor[4]))
		end
		
		if myMenu.Draw.w and spellReady(_W) and ballObj then
      		DrawCircle(ballObj.x, ballObj.y, ballObj.z, 250, ARGB(myMenu.Draw.wColor[1], myMenu.Draw.wColor[2], myMenu.Draw.wColor[3], myMenu.Draw.wColor[4]))
		end
		
		if myMenu.Draw.e and spellReady(_E) then
      		DrawCircle(myHero.x, myHero.y, myHero.z, 1100, ARGB(myMenu.Draw.eColor[1], myMenu.Draw.eColor[2], myMenu.Draw.eColor[3], myMenu.Draw.eColor[4]))
		end
		
		if myMenu.Draw.r and spellReady(_R) and ballObj then
      		DrawCircle(ballObj.x, ballObj.y, ballObj.z, 400, ARGB(myMenu.Draw.rColor[1], myMenu.Draw.rColor[2], myMenu.Draw.rColor[3], myMenu.Draw.rColor[4]))
		end
		
		if ballObj and myMenu.Draw.ball then
			DrawCircle(ballObj.x, ballObj.y, ballObj.z, 80, ARGB(myMenu.Draw.ballColor[1], myMenu.Draw.ballColor[2], myMenu.Draw.ballColor[3], myMenu.Draw.ballColor[4]))
		end
	end
	
	if myMenu.Draw.damage then
		for i, enemy in pairs(enemies) do
			if enemy and enemy.visible and not enemy.dead then
				
				local p = WorldToScreen(D3DXVECTOR3(enemy.x, enemy.y, enemy.z))
				
				if OnScreen(p.x, p.y) then
					local textLabel = nil
					local line = 2
					local linePosA  = {x = 0, y = 0 }
					local linePosB  = {x = 0, y = 0 }
					local TextPos   = {x = 0, y = 0 }
					local myDmg = MATH_GetDamage("ALL", enemy)
					
					if myDmg >= enemy.health then
						myDmg = enemy.health - 1
						textLabel = "Killable"
					else
						textLabel = "Damage"
					end
					
					myDmg = math.round(myDmg)
					local StartPos, EndPos = MATH_GetHPBarPos(enemy)
          			local Real_X = StartPos.x + 24
          			local Offs_X = (Real_X + ((enemy.health - myDmg) / enemy.maxHealth) * (EndPos.x - StartPos.x - 2))
          			
					if Offs_X < Real_X then
            			Offs_X = Real_X 
          			end 
					
					local mytrans = 350 - math.round(255*((enemy.health-myDmg)/enemy.maxHealth))
          			if mytrans >= 255 then 
            			mytrans = 254 
          			end
					
          			local my_bluepart = math.round(400*((enemy.health-myDmg)/enemy.maxHealth))
          			if my_bluepart >= 255 then 
            			my_bluepart = 254 
          			end
					
          			linePosA.x = Offs_X-150
          			linePosA.y = (StartPos.y-(30+(line*15)))    
          			linePosB.x = Offs_X-150
          			linePosB.y = (StartPos.y-10)
          			TextPos.x = Offs_X-148
          			TextPos.y = (StartPos.y-(30+(line*15)))
					
          			if myDmg > 0 then
            			DrawLine(linePosA.x, linePosA.y, linePosB.x, linePosB.y, 1, ARGB(mytrans, 255, my_bluepart, 0))
            			DrawText(tostring(myDmg).." "..tostring(textLabel), 15, TextPos.x, TextPos.y , ARGB(mytrans, 255, my_bluepart, 0))
          			end
				end
			end
		end
	end
end

function OnWndMsg(msg, key)
	if msg == WM_LBUTTONDOWN and not myHero.dead and myMenu.Misc.target then
		for i, e in ipairs(enemies) do
			if e and TARGETING_UnitValid(e) and GetDistance(mousePos, e) <= 120 and e.type == myHero.type and e.team ~= myHero.team then
				if e == focusTarget then
					focusTarget = nil
					PrettyPrint("Removed [" .. e.charName .. "] as target.", false)
					return
				else
					focusTarget = e
					PrettyPrint("Set target as [" .. e.charName .. "].", false)
					return
				end
			end
		end
	end
end

function OnCreateObj(obj)
	if obj.valid and obj.team == myHero.team then
		if obj.type == "MissileClient" and (obj.spellName == "OrianaIzuna" or obj.spellName == "OrianaRedact") then
			ballObj = obj
		elseif obj.name == "TheDoomBall" then
			ballObj = obj
		elseif obj.name:lower() == "yomu_ring_green" then
			ballObj = obj
		elseif obj.name:lower() == "orianna_ball_flash_reverse" then
			ballObj = myHero
		end
	end
end

function OnApplyBuff(unit, buff)
	if unit ~= nil and buff ~= nil and buff.name ~= nil and unit.isMe and buff then
		if buff.name:lower() == "recall" then
			isRecalling = true
		elseif buff.name:lower() == "summonerteleport" then
			isRecalling = true
		elseif buff.name:lower() == "recallimproved" then
			isRecalling = true
		end
	end
end

function OnUpdateBuff(unit, buff)
	if unit ~= nil and unit.isMe and buff ~= nil and buff.name == "orianaghostself" then
		hasBall = true
	end
	if unit ~= nil and unit.team == myHero.team and buff ~= nil and (buff.name == "orianaredactshield" or buff.name == "orianaghost") then
		ballObj = unit
	end
end

function OnRemoveBuff(unit, buff)
	if unit ~= nil and unit.isMe and buff ~= nil and buff.name == "orianaghostself" then
		hasBall = false
	end
	if unit ~= nil and buff and unit.isMe and buff.name:lower() == "recall" or buff.name:lower() == "summonerteleport" or buff.name:lower() == "recallimproved" then
		isRecalling = false
	end
end

function OnCastSpell(iSpell, startPos, endPos, targetUnit)
	if myMenu.Auto.blockR and iSpell == 3 and CountEnemyHeroInRange(skillData["R"]["range"], ballObj) == 0 then
		BlockSpell()
		PrettyPrint("Block: R [no one in range]", true)
	end
end

function OnProcessSpell(unit, spell)
	if unit.type == "obj_AI_Hero" then
		lastChampSpell[unit.networkID] = {name = spell.name, time = os.clock()}
	end
	
	if unit.type == myHero.type and unit.team == myHero.team and not unit.isMe and spellReady(_E) then
		for mChampion, mSpell in pairs(engageList) do
			if mSpell.name == spell.name then
				CastSpell(_E, unit)
				PrettyPrint("Spell: E [engage " .. spell.name .. "]", true)
				return
			end
		end
	end
	
	if unit.type == myHero.type and unit.team ~= myHero.team and spell ~= nil then
		--Process spells at me
		if isUnit[unit.charName] and GetDistance(unit) < 2000 then
			if spell.name == (type(isUnit[unit.charName].spell) == 'number' and unit:GetSpellData(isUnit[unit.charName].spell).name or isUnit[unit.charName].spell) then
				if spell.target ~= nil and spell.target.isMe or isUnit[unit.charName].spell == 'blindmonkqtwo' and spellReady(_E) then
					CastSpell(_E, myHero)
					PrettyPrint("Spell: E [sheild " .. spell.name .. "]", true)
					return
				else
					spellExpired = false
					informationTable = {
						spellSource = unit,
						spellCastedTick = GetTickCount(),
						spellStartPos = Point(spell.startPos.x, spell.startPos.z),
						spellEndPos = Point(spell.endPos.x, spell.endPos.z),
						spellRange = isUnit[unit.charName].range,
						spellSpeed = isUnit[unit.charName].projSpeed
					}
					PrettyPrint("Tracking spell " .. spell.name .. " from " .. unit.charName, true)
				end
			end
		end
		
		if myMenu.Interrupt.r and interruptSpells[unit.charName] ~= nil and spellReady(_R) and myMenu.Interrupt["spell" .. interruptSpells[unit.charName].stop.spellName] == spell.name then
			if GetDistance(ballObj, unit) < 375 then
				CastSpell(_R)
				PrettyPrint("Interrupting spell " .. spell.name .. " from " .. unit.charName, true)
				return
			end
		end
		
		
	end
	
	if unit and spell and unit.isMe and spell.target and spell.name:lower():find("orianaredactcommand") then --E cast
		ballObj = spell.target
	end
end

function OnGainBuff(unit, buff)
	if unit and buff and unit.team == myHero.team and buff.name and buff.name:lower():find("orianaghostself") then
		ballObj = unit
	end
end

function SpellExpired()
	if informationTable ~= {} and informationTable.spellCastedTick and not spellExpired and (GetTickCount() - informationTable.spellCastedTick) <= (informationTable.spellRange / informationTable.spellSpeed) * 1000 then
		local spellDirection = (informationTable.spellEndPos - informationTable.spellStartPos):normalized()
		local spellStartPosition = informationTable.spellStartPos + spellDirection
		local spellEndPosition   = informationTable.spellStartPos + spellDirection * informationTable.spellRange
		local heroPosition = Point(myHero.x, myHero.z)
		local lineSegment = LineSegment(Point(spellStartPosition.x, spellStartPosition.y), Point(spellEndPosition.x, spellEndPosition.y))
		--local lineSegment = LineSegment(Point(spellStartPosition.x, spellStartPosition.y), Point(spellEndPosition.x, spellEndPosition.y))
		if lineSegment:distance(heroPosition) <= 350 and spellReady(_E) then
			CastSpell(_E, myHero)
			PrettyPrint("Spell: E [block spell]", true)
			return true
		end
	else
		spellExpired = true
		informationTable = {}
	end
end

function OnProcessAttack(unit, spell)
	if myMenu.Auto.e and unit and spell and unit.team and unit.team ~= myHero.team and unit.type == "obj_AI_Turret" and spellReady(_E) then --Auto sheild tower shot
		if spell.target.isMe then
			CastSpell(_E, myHero)
			PrettyPrint("Spell: E [tower shot]", true)
			return
		elseif spell.target.maxHealth / 2 >= spell.target.health and GetDistance(myHero, unit) < skillData["E"]["range"] then
			CastSpell(_E, spell.target)
			PrettyPrint("Spell: E [low hp]", true)
			return
		end
	elseif myMenu.Auto.e and unit and spell and unit.team and unit.team ~= myHero.team and unit.type == myHero.type and spellReady(_E) and spell.name:find("CritAttack") and spell.target and spell.target.isMe then --Auto sheild crit
		CastSpell(_E, myHero)
		PrettyPrint("Spell: E [crit]", true)
		return
	elseif myMenu.Auto.e and unit and spell and unit.team and unit.team ~= myHero.team and unit.type == myHero.type and spell.name:find("SummonerDot") and spellReady(_E) then --Auto sheild ignite
		CastSpell(_E, spell.target)
		PrettyPrint("Spell: E [ignite]", true)
		return
	end
end

function OnTick()
	if myHero.dead then return end
	
	if not ballObj then
		ORI_CheckAllyWithBall()
	end
	
	if not myMenu.Misc.target and focusTarget then
		focusTarget = nil
	end
	
	SpellExpired()
	EngageCheck()
	if AutoIgnite() then
		return
	end
	tickHerosInRangeMe = CountEnemyHeroInRange(skillData["R"]["range"], myHero)
	tickHerosInRangeBall240 = CountEnemyHeroInRange(240, ballObj)
	tickHerosInRangeBall400 = CountEnemyHeroInRange(390, ballObj)
	
	CheckSelectedTarget()
	
	if AutoSmite() then
		return
	end
	
	if AutoUsePotion() then
		return
	end
	
	if KillSecure() then
		return
	end
	
	if myMenu.Auto.r and spellReady(_R) and tickHerosInRangeBall400 >= myMenu.Auto.rEnemys then
		CastSpell(_R)
		return
	end
	
	if myMenu.Keys.Flee then
		FleeMode()
		return
	end
	
	if myMenu.Keys.Combo and ComboMode() then
		return
	end
	
	if myMenu.Keys.Harass and HarassMode() then
		return
	end
	
	if myMenu.Keys.harass and HarassMode() then
		return
	end
	
	if myMenu.Keys.LaneClear then
		if myMenu.Keys.harassInLaneClear and HarassMode() then
			return
		end
		LaneClearMode()
	end
	
	if myMenu.Keys.JungleClear then
		JungleClearMode()
	end
	
	if AutoE() then
		return
	end
	
	if myMenu.Keys.harass and HarassMode() then
		return
	end
end

function FleeMode()
	if GetDistance(mousePos) > 1 then
    	local moveToPos = myHero + (Vector(mousePos) - myHero):normalized() * 300
    	myHero:MoveTo(moveToPos.x, moveToPos.z)
  	end
	if hasBall and spellReady(_W) and tickHerosInRangeMe >= 1 then
		CastSpell(_W)
		PrettyPrint("Flee: W", true)
		return true
	elseif spellReady(_E) then
		CastSpell(_E, myHero)
		PrettyPrint("Flee: E", true)
		return true
	end
end

function ComboMode()
	target = TARGETING_GetTarget()
	if MATH_IsTeamFight() and ComboMode_TeamFight() then
		return true
	end

	--Auto W when atleast 1 in range
	if ballObj and myMenu.Combo.w and spellReady(_W) and tickHerosInRangeBall240 >= 1 then
		CastSpell(_W)
		PrettyPrint("Combo: W [>=1]", true)
		return true
	end

	--Auto E when enemys too close
	--[[if myMenu.Combo.e and not hasBall and spellReady(_E) and CountEnemyHeroInRange(240, myHero) >= 1 then
		CastSpell(_E, myHero)
		return true
	end]]--

	if myMenu.Combo.e and spellReady(_E) and ballObj then
		local line = MATH_CountObjectsOnLineSegment(ballObj.pos, myHero.pos, skillData["E"]["width"], enemies)
		if line >= 1 then
			CastSpell(_E, myHero)
			PrettyPrint("Combo: E [" .. line .. ">=1]", true)
			return true
		end
	end
	
	--Cast on target
	if target then

		--Cast Q on target
		if myMenu.Combo.q and spellReady(_Q) then
			local pos, hc, info = FHPrediction.GetPrediction("Q", target)
			if pos and hc > 0 and GetDistance(myHero, pos) <= skillData["Q"]["range"] then
				CastSpell(_Q, pos.x, pos.z)
				PrettyPrint("Combo: Q [" .. target.charName .. "]", true)
				return true
			end
		end
		
		--Cast R on target
		if ballObj and myMenu.Combo.r and spellReady(_R) and tickHerosInRangeBall400 >= myMenu.Combo.rEnemys then
			CastSpell(_R)
			PrettyPrint("Combo: R [" .. tickHerosInRangeBall400 .. ">=" .. myMenu.Combo.rEnemys .. "]", true)
			return true
		end
	end

	return false
end

function ComboMode_TeamFight()
	--W Team Fight Logic
	if myMenu.TeamCombo.w and spellReady(_W) then
		if tickHerosInRangeBall240 >= myMenu.TeamCombo.wEnemys then
			CastSpell(_W)
			PrettyPrint("Team Combo: W [" .. tickHerosInRangeBall240 .. ">=" .. myMenu.TeamCombo.wEnemys .. "]", true)
			return true
		end
		
		if target and GetDistance(ballObj, target) <= skillData["W"]["width"] then
			CastSpell(_W)
			PrettyPrint("Team Combo: W [" .. target .. " in range]", true)
			return true
		end
	end
	
	--Q Team Fight Logic
	
	if myMenu.TeamCombo.q and spellReady(_Q) then
		if ballObj then
			local qTarget = nil
			local qCount = 0
			local posQ, hcQ, infoQ = nil, nil, nil
			for q, en in pairs(enemies) do
				if en and TARGETING_UnitValid(en) and GetDistance(myHero, en) <= skillData["Q"]["range"] then
					local pos, hc, info = FHPrediction.GetPrediction("Q", en)
					if hc > 0 and GetDistance(pos, myHero) <= skillData["Q"]["range"] then
						local qTmpTarget = en
						local qTmpCount = MATH_CountObjectsOnLineSegment(ballObj.pos, pos, skillData["Q"]["width"], enemies)
						if qTarget == nil or qCount < qTmpCount then
							qTarget = qTmpTarget
							qCount = qTmpCount
							posQ, hcQ, infoQ = pos, hc, info
						end
					end
				end
			end
			if qTarget ~= nil and qCount >= 2 then
				if hcQ > 0 then
					CastSpell(_Q, posQ.x, posQ.z)
					PrettyPrint("Team Combo: Q [" .. qCount .. ">=2]", true)
					return true
				end
			end
		end
		
		if GetDistance(myHero, target) <= skillData['Q']['range'] then
			local pos, hc, info = FHPrediction.GetPrediction("Q", target)
			if hc > 0 and GetDistance(myHero, pos) <= skillData['Q']['range'] then
				CastSpell(_Q, pos.x, pos.z)
				PrettyPrint("Team Combo: Q [" .. target .. "]", true)
				return true
			end
		end
	end
	
	if myMenu.TeamCombo.e and spellReady(_E) then
		if ballObj then
			local bestHit = nil
			local bestHitCount = 0
			for q, al in pairs(allies) do
				if al and TARGETING_UnitValid(al) and GetDistance(al, myHero) <= skillData["E"]["range"] then
					local line = MATH_CountObjectsOnLineSegment(ballObj.pos, al.pos, skillData["E"]["width"], enemies)
					if line > 0 then
						if bestHit and bestHitCount and bestHitCount < line then
							bestHit = al
							bestHitCount = line
						else
							bestHit = al
							bestHitCount = line
						end
					end
				end
			end
			
			if bestHitCount >= myMenu.TeamCombo.eEnemys and bestHit then
				CastSpell(_E, bestHit)
				PrettyPrint("Team Combo: E [" .. bestHitCount .. ">=" .. myMenu.TeamCombo.eEnemys .. "]", true)
				return true
			end
		end
	end
	
	if ballObj and myMenu.TeamCombo.r and spellReady(_R) and tickHerosInRangeBall400 >= myMenu.TeamCombo.rEnemys then
		CastSpell(_R)
		PrettyPrint("Team Combo: R [" .. tickHerosInRangeBall400 .. ">=" .. myMenu.TeamCombo.rEnemys .. "]", true)
		return true
	end
end

function AutoE()
	if myMenu.Auto.e and spellReady(_E) then
		--Self
		if myHero.maxHealth / 4 >= myHero.health and tickHerosInRangeMe >= 1 then
			CastSpell(_E, myHero)
			PrettyPrint("Auto E: E [protect self]", true)
			return true
		end
		
		local bestAlly = nil
		for i, ally in pairs(allies) do
			if ally and not ally.isDead and GetDistance(myHero, ally) <= 1100 and myHero.maxHealth / 4 >= myHero.health and CountEnemyHeroInRange(400, ally.pos) >= 1 then
				if not bestAlly then
					bestAlly = ally
				elseif bestAlly.health < ally.health then
					bestAlly = ally
				end
			end
		end
		if bestAlly then
			CastSpell(_E, bestAlly)
			PrettyPrint("Auto E: E [" .. bestAlly .. "]", true)
			return true
		end
	end
	return false
end

function KillSecure()
	if myMenu.KillSecure.q or myMenu.KillSecure.w or myMenu.KillSecure.e or myMenu.KillSecure.r then
		for i, enemy in pairs(enemies) do
			if TARGETING_UnitValid(enemy) then
				local dM = GetDistance(enemy, myHero)
				local dB = GetDistance(enemy, ballObj)
				if spellReady(_W) and dB <= skillData["W"]["width"] and MATH_GetDamage(_W, enemy) > enemy.health then
					CastSpell(_W)
					PrettyPrint("Kill Secure: W", true)
					return true
				end
				
				if spellReady(_Q) and dM <= skillData["Q"]["range"] and MATH_GetDamage(_Q, enemy) > enemy.health then
					local pos, hc, info = FHPrediction.GetPrediction("Q", enemy)
					if pos and hc > 0 and GetDistance(pos, myHero) <= skillData["Q"]["range"] then
						CastSpell(_Q, pos.x, pos.z)
						PrettyPrint("Kill Secure: Q", true)
						return true
					end
					return
				end
				
				if spellReady(_W) and spellReady(_Q) and dB <= skillData["W"]["width"] and MATH_GetDamage(_W, enemy) + MATH_GetDamage(_Q, enemy) > enemy.health then
					local pos, hc, info = FHPrediction.GetPrediction("Q", enemy)
					if pos and hc > 0 then
						CastSpell(_W)
						CastSpell(_Q, pos.x, pos.z)
						PrettyPrint("Kill Secure: WQ", true)
						return true
					end
				end
				
				if spellReady(_R) and dB <= skillData["R"]["width"] and MATH_GetDamage(_R, enemy) > enemy.health then
					CastSpell(_R)
					PrettyPrint("Kill Secure: R", true)
					return
				end
				
				if spellReady(_R) and spellReady(_W) and dB <= skillData["W"]["width"] and MATH_GetDamage(_R, enemy) + MATH_GetDamage(_W, enemy) > enemy.health then
					CastSpell(_R)
					CastSpell(_W)
					PrettyPrint("Kill Secure: RW", true)
					return
				end
				
				if spellReady(_R) and spellReady(_Q) and dB <= skillData["R"]["width"] and MATH_GetDamage(_R, enemy) + MATH_GetDamage(_Q, enemy) > enemy.health then
					local pos, hc, info = FHPrediction.GetPrediction("Q", enemy)
					if pos and hc > 0 then
						CastSpell(_R)
						CastSpell(_Q, pos.x, pos.z)
						PrettyPrint("Kill Secure: RQ", true)
						return true
					end
				end
				
				if spellReady(_W) and spellReady(_R) and spellReady(_Q) and dB <= skillData["W"]["width"] and MATH_GetDamage(_W, enemy) + MATH_GetDamage(_R, enemy) + MATH_GetDamage(_Q, enemy) > enemy.health then
					local pos, hc, info = FHPrediction.GetPrediction("Q", enemy)
					if pos and hc > 0 then
						CastSpell(_R)
						CastSpell(_W)
						CastSpell(_Q, pos.x, pos.z)
						PrettyPrint("Kill Secure: RWQ", true)
						return true
					end
				end
			end
		end
	end
	return false
end

function HarassMode()
	local target = TARGETING_GetTarget()
	
	if myMenu.Harass.w and GetManaPercent() >= myMenu.Harass.wMana and spellReady(_W) and CountEnemyHeroInRange(skillData["W"]["range"], ballObj) >= 1 then
		CastSpell(_W)
		PrettyPrint("Harass: W [>=1 in range]", true)
		return true
	end
	
	if target and myMenu.Harass.q and GetManaPercent() >= myMenu.Harass.qMana and spellReady(_Q) then
		local pos, hc, info = FHPrediction.GetPrediction("Q", target)
		if hc > 0 and GetDistance(pos, myHero) <= skillData["Q"]["range"] then
			CastSpell(_Q, pos.x, pos.z)
			PrettyPrint("Harass: Q [" .. target .. "]", true)
		end
	end
	
	if myMenu.Harass.e and GetManaPercent() >= myMenu.Harass.eMana and spellReady(_E) and ballObj then
		local line = MATH_CountObjectsOnLineSegment(ballObj.pos, myHero.pos, skillData["E"]["width"], enemies)
		if line >= 1 then
			CastSpell(_E, myHero)
			PrettyPrint("Harass: E [" .. line .. "]>=1", true)
			return true
		end
	end
	
end

function LaneClearMode()
	targetMinions:update()
	if ballObj and spellReady(_W) then
		local mHit = 0
		if ballObj.pos then
			mHit = GetMinionsHit(ballObj.pos, skillData["W"]["width"])
		else
			mHit = GetMinionsHit(ballObj, skillData["W"]["width"])
		end
		if mHit then
			if myMenu.LaneClear.UseW and GetManaPercent() >= myMenu.LaneClear.wMana and mHit >= 2 then
				CastSpell(_W)
				PrettyPrint("Lane Clear: W [" .. mHit .. ">=2]", true)
				return true
			end
		end
	end
	
	local bestMinion = nil
	local bestHit = 0
	for i, targetMinion in pairs(targetMinions.objects) do
		if targetMinion and TARGETING_UnitValid(targetMinion) then
			local distance = GetDistanceSqr(targetMinion)
			if myMenu.LaneClear.q and GetManaPercent() >= myMenu.LaneClear.qMana and spellReady(_Q) and distance < skillData["Q"]["range"] ^ 2 then
				local hit = GetLineMinionHitQ(targetMinion.pos)
				if hit > bestHit then
					bestMinion = targetMinion
					bestHit = hit
				end
			end
		end
	end
	if bestMinion and bestHit > 1 then
		local pos, hc, info = FHPrediction.GetPrediction("Q", bestMinion)
		if pos and hc > 0 and GetDistance(myHero, pos) <= skillData["Q"]["range"] then
			CastSpell(_Q, pos.x, pos.z)
			PrettyPrint("Lane Clear: Q [" .. bestHit .. ">=1]", true)
			return true
		end
	end
	return false
end

function JungleClearMode()
	jungleMinions:update()
	for i, jungleMinion in pairs(jungleMinions.objects) do
    	if not jungleMinion.name:find("Plant") then
      		if jungleMinion ~= nil and TARGETING_UnitValid(jungleMinion) then
				local distance = GetDistanceSqr(jungleMinion)
				if myMenu.JungleClear.q and GetManaPercent() >= myMenu.JungleClear.qMana and spellReady(_Q) and distance < skillData["Q"]["range"] ^ 2 then
					local pos, hc, info = FHPrediction.GetPrediction("Q", jungleMinion)
					if pos and hc > 0 and GetDistance(pos, myHero) <= skillData["Q"]["range"] then
						CastSpell(_Q, pos.x, pos.z)
						PrettyPrint("Jungle Clear: Q [" .. jungleMinion.charName .. "]", true)
						return true
					end
				end
				
				if myMenu.JungleClear.UseW and GetManaPercent() >= myMenu.JungleClear.wMana and spellReady(_W) and GetDistanceSqr(ballObj, jungleMinion) < skillData["W"]["range"] ^ 2 then
					CastSpell(_W)
					PrettyPrint("Jungle Clear: W [" .. jungleMinion.charName .. "]", true)
					return true
				end
			end
    	end
	end
	return false
end

function AutoBuyStarting()
	if VIP_USER and myMenu.Auto.buy and GetGameTimer() < 200 and myHero.gold == 500 then
		DelayAction(function()
			BuyItem(1056) --Dorans Ring
		end, 1)
		DelayAction(function()
			BuyItem(2003) --HP Pot
		end, 3)
		DelayAction(function()
			BuyItem(2003) --HP Pot
		end, 5)
		DelayAction(function()
			BuyItem(3340) --Trinket
		end, 7)
	end
end

function EngageCheck()
	--[[if not spellReady(_E) then return false end
	for i, unit in ipairs(GetAllyHeroes()) do
		if unit and TARGETING_UnitValid(unit) and GetDistance(myHero, unit) <= skillData["E"]["range"] then
			for champion, spell in pairs(engageList) do
				if lastChampSpell[unit.networkID] and lastChampSpell[unit.networkID].name ~=nil and myMenu.Engage[champion.. lastChampSpell[unit.networkID].name] and (os.clock() - lastChampSpell[unit.networkID].time < 1.5) then
					CastSpell(_E, unit)
					PrettyPrint("Engage: E [" .. unit.charName .. " " .. lastChampSpell[unit.networkID].name .. "]", true)
					return true
				end
			end
		end
	end]]--
	return false
end

--ORI SPECIFIC--
function ORI_CheckAllyWithBall()
	for i, ally in pairs(allies) do
		for i = 1, ally.buffCount do
			local buff = ally:getBuff(i)
			if buff and buff.valid and (buff.name == "orianaredactshield" or buff.name == "orianaghost") then 
				ballObj = ally
			end
		end
	end
	for i = 1, objManager.maxObjects do
		local obj = objManager:GetObject(i)
		if obj ~= nil and obj.team == myHero.team and obj.name == "TheDoomBall" then
			ballObj = obj
		end
	end
end
--END ORI SPECIFIC--

--MATH--
function MATH_CountObjectsOnLineSegment(StartPos, EndPos, width, objects)
	if not StartPos or not EndPos or not width or not objects then return 0 end
	local n = 0
	for i, object in pairs(objects) do
		if object.valid and not object.dead then
			local pointSegment, pointLine, isOnSegment = VectorPointProjectionOnLineSegment(StartPos, EndPos, object)
   			local pointSegment3D = {x = pointSegment.x, y = object.y, z = pointSegment.y}
   			if isOnSegment and pointSegment3D and GetDistanceSqr(pointSegment3D, object) < ((object.boundingRadius + width) ^ 2) then
    			n = n + 1
   			end
		end
	end
	return n
end

function GetMinionsHit(Pos, radius)
	local count = 0
	if Pos and radius then return 0 end
	for i, minion in pairs(targetMinions.objects) do 
		if minion and TARGETING_UnitValid(minion) and GetDistance(Pos, minion.pos) < radius then
			count = count + 1
		end
	end
  	return count
end

function GetLineMinionHitE(Pos, returnTarget)
	local count = 0
	local StartPoint = Vector(Pos.x, 0, Pos.z)
	local EndPoint = Vector(returnTarget.x, 0, returnTarget.z)
	for i, minion in pairs(targetMinions.objects) do
		local position = Vector(minion.x, 0, minion.z)
		local PointInLine = VectorPointProjectionOnLineSegment(StartPoint, EndPoint, position)
		if GetDistance(PointInLine, position) < Eradius then
			count = count + 1
		end
	end
	return count
end

function GetLineMinionHitQ(Pos)
	local count = 0
	if not ballObj then return count end
	local StartPoint = Vector(Pos.x, 0, Pos.z)
	local EndPoint = Vector(ballObj.x, 0, ballObj.z)
	for i, minion in pairs(targetMinions.objects) do
		local position = Vector(minion.x, 0, minion.z)
		local PointInLine = VectorPointProjectionOnLineSegment(StartPoint, EndPoint, position)
		if GetDistance(PointInLine, position) < skillData["E"]["width"] then
			count = count + 1
		end
	end
	return count
end

function MATH_GetHPBarPos(enemy)
    enemy.barData = {PercentageOffset = {x = -0.05, y = 0}}
    local barPos = GetUnitHPBarPos(enemy)
    local barPosOffset = GetUnitHPBarOffset(enemy)
    local barOffset = { x = enemy.barData.PercentageOffset.x, y = enemy.barData.PercentageOffset.y }
    local barPosPercentageOffset = { x = enemy.barData.PercentageOffset.x, y = enemy.barData.PercentageOffset.y }
    local BarPosOffsetX = -50
    local BarPosOffsetY = 46
    local CorrectionY = 39
    local StartHpPos = 31 
    barPos.x = math.floor(barPos.x + (barPosOffset.x - 0.5 + barPosPercentageOffset.x) * BarPosOffsetX + StartHpPos)
    barPos.y = math.floor(barPos.y + (barPosOffset.y - 0.5 + barPosPercentageOffset.y) * BarPosOffsetY + CorrectionY)
    local StartPos = Vector(barPos.x , barPos.y, 0)
    local EndPos = Vector(barPos.x + 108 , barPos.y , 0)    
    return Vector(StartPos.x, StartPos.y, 0), Vector(EndPos.x, EndPos.y, 0)
end

function MATH_GetDamage(spell, unit)
	if spell == "ALL" then
		return skillData["Q"].damage(unit) + skillData["W"].damage(unit) + skillData["E"].damage(unit) + skillData["R"].damage(unit)
	end
	if spell == _Q then
		return skillData["Q"].damage(unit)
	end
	if spell == _W then
		return skillData["W"].damage(unit)
	end
	if spell == _E then
		return skillData["E"].damage(unit)
	end
	if spell == _R then
		return skillData["R"].damage(unit)
	end
	
end

function MATH_IsTeamFight()
	if CountEnemyHeroInRange(1000, myHero) >= 2 then
		return true
	end
	return false
end

function GetManaPercent()
	return 100 * myHero.mana / myHero.maxMana
end
--END MATH--

--MISC--
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
--END MISC--

--TARGETING--
local dontAttack = {"undyingrage", "sionpassivezombie", "aatroxpassivedeath", "chronoshift", "judicatorintervention"}

function TARGETING_GetTarget()
	ts:update()
	if focusTarget and myMenu.Misc.target and TARGETING_UnitValid(focusTarget) and GetDistance(focusTarget, myHero) < 900 then
		return focusTarget
	elseif ts.target and TARGETING_UnitValid(ts.target) and GetDistance(ts.target, myHero) < 900 then
		return ts.target
	else
		if myMenu.Misc.targetMode == 3 then --Most Fed TODO: Add for most kills
			local bTarget = nil
			for i, e in ipairs(enemies) do
				if e and TARGETING_UnitValid(e) and GetDistance(myHero, e) <= 900 then
					if bTarget then
						if bTarget.health > e.health then
							bTarget = e
						end
					else
						bTarget = e
					end
				end
			end
			if bTarget then
				return bTarget
			end
		else  --Auto / Least HP
			local bTarget = nil
			for i, e in ipairs(enemies) do
				if e and TARGETING_UnitValid(e) and GetDistance(myHero, e) <= 900 then
					if bTarget then
						if bTarget.health > e.health then
							bTarget = e
						end
					else
						bTarget = e
					end
				end
			end
			if bTarget then
				return bTarget
			end
		end
	end
	return nil
end

function CheckDontAttack(unit)
  for i,buff in pairs(dontAttack) do
    if TargetHaveBuff(buff, unit) then
      return true
    end
  end
    return false
end

function DrawTarget()
	if focusTarget and myMenu.Misc.target and TARGETING_UnitValid(focusTarget) then
		DrawCircle2(focusTarget.pos.x, focusTarget.pos.y, focusTarget.pos.z, 4, ARGB(255,255,0,0))
	elseif target and TARGETING_UnitValid(target) then
		DrawCircle2(target.pos.x, target.pos.y, target.pos.z, 4, ARGB(255,255,0,0))
	end
end

function CheckSelectedTarget()
	if focusTarget and focusTarget.isDead then
		PrettyPrint("Removed [" .. focusTarget.charName .. "] as target.", false)
		focusTarget = nil
	elseif focusTarget and not TARGETING_UnitValid(focusTarget) then
		PrettyPrint("Removed [" .. focusTarget.charName .. "] as target.", false)
		focusTarget = nil
	end
	
	if target and target.isDead then
		target = nil
	elseif target and not TARGETING_UnitValid(target) then
		target = nil
	end
	
	if focusTarget and target ~= focusTarget then
		target = focusTarget
	end
end

function TARGETING_UnitValid(unit)
	if unit and ValidTarget(unit) and not unit.isDead and not CheckDontAttack(unit) then return true end
	return false
end
--END TARGETING--

--DRAWING--
function DrawCircleNextLvl(x, y, z, radius, width, color, chordlength)
	radius = radius or 300
  	quality = math.max(8,math.floor(180/math.deg((math.asin((chordlength/(2*radius)))))))
  	quality = 2 * math.pi / quality
  	local points = {}
  	for theta = 0, 2 * math.pi + quality, quality do
    	local c = WorldToScreen(D3DXVECTOR3(x + radius * math.cos(theta), y, z - radius * math.sin(theta)))
    	points[#points + 1] = D3DXVECTOR2(c.x, c.y)
  	end
  	DrawLines2(points, width or 1, color or 4294967295)
end

function DrawCircle2(x, y, z, radius, color)
  	local vPos1 = Vector(x, y, z)
  	local vPos2 = Vector(cameraPos.x, cameraPos.y, cameraPos.z)
  	local tPos = vPos1 - (vPos1 - vPos2):normalized() * radius
  	local sPos = WorldToScreen(D3DXVECTOR3(tPos.x, tPos.y, tPos.z))
  	if OnScreen({ x = sPos.x, y = sPos.y }, { x = sPos.x, y = sPos.y })  then
    	DrawCircleNextLvl(x, y, z, radius, 1, color, 75)
  	end
end
--END DRAWING--

--POTION USAGE--
local lastPotionTime = os.clock()
local lastPotionDur = 0
function AutoUsePotion()
	if myMenu.Items.Potion.use and os.clock() - lastPotionTime > lastPotionDur and not InFountain() and (myHero.health*100)/myHero.maxHealth < myMenu.Items.Potion.hp then
		for SLOT = ITEM_1, ITEM_6 do
			if myHero:GetSpellData(SLOT).name == "RegenerationPotion" and myMenu.Items.Potion.healthpot then
				PrettyPrint("Using potion [Health Potion]", true)
				CastSpell(SLOT)
				lastPotionDur = 15
				lastPotionTime = os.clock()
				return true
			elseif myHero:GetSpellData(SLOT).name == "ItemMiniRegenPotion" and myMenu.Items.Potion.healthcookie then
				PrettyPrint("Using potion [Cookie]", true)
				CastSpell(SLOT)
				lastPotionDur = 15
				lastPotionTime = os.clock()
				return true
			elseif myHero:GetSpellData(SLOT).name == "ItemCrystalFlaskJungle" and myMenu.Items.Potion.hunterspot then
				PrettyPrint("Using potion [Hunters Potion]", true)
				CastSpell(SLOT)
				lastPotionDur = 8
				lastPotionTime = os.clock()
				return true
			elseif myHero:GetSpellData(SLOT).name == "ItemCrystalFlask" and myMenu.Items.Potion.refillablepot then
				PrettyPrint("Using potion [Refillable Potion]", true)
				CastSpell(SLOT)
				lastPotionDur = 12
				lastPotionTime = os.clock()
				return true
			elseif myHero:GetSpellData(SLOT).name == "ItemDarkCrystalFlask" and myMenu.Items.Potion.corruptingpot then
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
--END POTION USAGE--

--SMITE--
local smiteList = {"summonersmite", "s5_summonersmiteplayerganker", "s5_summonersmiteduel"}
local smiteMobs = {"SRU_Blue1.1.1", "SRU_Blue7.1.1", "SRU_Murkwolf2.1.1", "SRU_Murkwolf8.1.1", "SRU_Gromp13.1.1", "SRU_Gromp14.1.1", "Sru_Crab16.1.1", "Sru_Crab15.1.1", "SRU_Red10.1.1", "SRU_Red4.1.1", "SRU_Krug11.1.2", "SRU_Krug5.1.2", "SRU_Razorbeak9.1.1", "SRU_Razorbeak3.1.1", "SRU_Dragon6.1.1", "SRU_Baron12.1.1", "TT_NWraith1.1.1", "TT_NGolem2.1.1", "TT_NWolf3.1.1", "TT_NWraith4.1.1", "TT_NGolem5.1.1", "TT_NWolf6.1.1", "TT_Spiderboss8.1.1"}
local smiteSlot = nil
local dmgSmite = false

function LoadSmite()
	smiteSlot = GetSmiteSlot()
end

function GetSmiteDamage(unit)
	if smiteSlot and myMenu.Summoner.smite then
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

function GetSmiteSlot()
  for i=1, 3 do
    if FindSlotByName(smiteList[i]) ~= nil then
      smiteSlot = FindSlotByName(smiteList[i])
      smiteSlot = true
      if i == 2 or i == 3 then
        dmgSmite = true
      else
        dmgSmite = false
      end
    end
  end
end

function AutoSmite()
	if smiteSlot == nil or not myMenu.Summoner.smite then return false end
	local SmiteDmg = GetSmiteDamage()
	for _, minion in pairs(minionManager(MINION_JUNGLE, 500, myHero, MINION_SORT_MAXHEALTH_DEC).objects) do
		if not minion.dead and minion.visible and ValidTarget(minion, 500) then
			if Menu.Smite[minion.charName:gsub("_", "")] or string.lower(minion.charName):find("dragon") then
				if CanCast(smiteSlot) and GetDistance(myHero, minion) <= 500 and SmiteDmg >= minion.health then
					CastSpell(smiteSlot, minion)
					PrettyPrint("Smite: [" .. minion.charName .. "]", true)
					return true
				end
			end
		end
	end
	return false
end

function DrawSmiteable()
	if smiteSlot == nil or not myMenu.Summoner.smite then return end
	local SmiteDmg = GetSmiteDamage()
	for _, minion in pairs(minionManager(MINION_JUNGLE, 500, myHero, MINION_SORT_MAXHEALTH_DEC).objects) do
		for j = 1, #smiteMobs do
			if minion.name == smiteMobs[j] then
				if not minion.dead and minion.visible and ValidTarget(minion, 500) then
					if CanCast(smiteSlot) and GetDistance(myHero, minion) <= 500 and SmiteDmg >= minion.health then
						local posMinion = WorldToScreen(D3DXVECTOR3(minion.x, minion.y, minion.z))
						DrawText("Smite!", 20, posMinion.x, posMinion.y, ARGB(255,255,0,0))
					end
				end
			end
		end
	end
end
--END SMITE--

--IGNITE--
local igniteSlot = nil
function AutoIgnite()
	if igniteSlot == nil or not myMenu.Summoner.ignite then return false end
	for i,enemy in pairs(GetEnemyHeroes()) do
		if TARGETING_UnitValid(enemy) and igniteSlot and GetDistance(myHero, enemy) <= 600 and ((50 + (20*myHero.level))) >= enemy.health and igniteSlot ~= nil and myHero:CanUseSpell(igniteSlot) == READY then
			CastSpell(igniteSlot, enemy)
			PrettyPrint("Ignite: [" .. enemy.charName .. "]", true)
			return true
		end
	end
	return false
end
--END IGNITE--