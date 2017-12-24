local myMenu = nil
local scriptVersion = "1"
local isDebug = true
local m = nil


function CalcVector(source,target)
	local V = Vector(source.x, source.y, source.z)
	local V2 = Vector(target.x, target.y, target.z)
	local vec = V-V2
	local vec2 = vec:normalized()
	return vec2
end


function DrawLine3D2(x1, y1, z1, x2, y2, z2, width, color)
    local p = WorldToScreen(D3DXVECTOR3(x1, y1, z1))
    local px, py = p.x, p.y
    local c = WorldToScreen(D3DXVECTOR3(x2, y2, z2))
    local cx, cy = c.x, c.y
    DrawLine(cx, cy, px, py, width or 1, color or 4294967295)
end

function PrettyPrint(message, isDebug)
	if isDebug and not showDebug then return end
	if m == message then
		return
	end
	print("<font color=\"#FF5733\">[<b><i>0Aware</i></b>]</font> <font color=\"#3393FF\">" .. message .. "</font>")
	m = message
end

--
--
--START: Update
--
--
local AUTOUPDATE = false
local UPDATE_HOST = "raw.githubusercontent.com"
local UPDATE_PATH = "/azero/LeagueBoL/master/0Aware.lua".."?rand="..math.random(1,10000)
local UPDATE_FILE_PATH = SCRIPT_PATH..GetCurrentEnv().FILE_NAME
local UPDATE_URL = "https://"..UPDATE_HOST..UPDATE_PATH

if AUTOUPDATE then
	local ServerData = GetWebResult(UPDATE_HOST, "/azero/LeagueBoL/master/0Aware.ver")
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
	local ServerData = GetWebResult(UPDATE_HOST, "/azero/LeagueBoL/master/0Aware.msg")
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
--START: Gank Alert
--
--
function GANKALERT_Menu()
	myMenu:addSubMenu("--[[ Gank Alert ]]--", "Gank")
		myMenu.Gank:addParam("use", "Use Alert", SCRIPT_PARAM_ONOFF, true)
		myMenu.Gank:addParam("info2", " ", SCRIPT_PARAM_INFO, "")
		myMenu.Gank:addParam("range", "Max Range", SCRIPT_PARAM_SLICE, 5000, 50, 10000, 0)
		myMenu.Gank:addParam("info2", " ", SCRIPT_PARAM_INFO, "")
		myMenu.Gank:addParam("wide", "Line Width", SCRIPT_PARAM_SLICE, 4, 1, 8, 0)
		myMenu.Gank:addParam("text", "Text Size", SCRIPT_PARAM_SLICE, 20, 1, 40, 0)
		myMenu.Gank:addParam("lineonly", "Draw Lines Only", SCRIPT_PARAM_ONOFF, false)
		myMenu.Gank:addParam("info2", " ", SCRIPT_PARAM_INFO, "")
		for _, v in pairs(enemys) do
			myMenu.Gank:addParam("bl"..v.charName,v.charName, SCRIPT_PARAM_ONOFF, false)
		end
end

function GANKALERT_Draw()
	if not enemys or not myMenu or not myMenu.Gank.use then return end
	for _,v in pairs(enemys) do
		if GetDistance(v) > 4001 then
			color = ARGB(255, 0, 255, 0)
		elseif GetDistance(v) > 2500  then
			color = ARGB(255, 255, 215, 0)
		elseif GetDistance(v) < 2500  then
			color = ARGB(255,255,0,0)
		end
		
		if v and v.valid and not v.dead and v.visible and not myMenu.Gank["bl"..v.charName] and GetDistance(v) <= myMenu.Gank.range then
			DrawLine3D2(v.x, v.y, v.z, myHero.x, myHero.y, myHero.z, myMenu.Gank.wide, color)
			local V = CalcVector(myHero,v)*-250
			if not myMenu.Gank.lineonly then
				DrawText3D(v.charName..": "..math.round(GetDistance(v,myHero)),V.x+myHero.x,V.y+myHero.y,V.z+myHero.z, myMenu.Gank.text,color)
			end
		end
	end
end
--
--
--END: Gank Alert
--
--


function OnLoad()
	PrettyPrint("Welcome To Zer0 Awareness " .. GetUser() .. " - Version: " .. scriptVersion .. " - By: AZer0", false)
	PrettyPrint("This script is still in BETA please let me know any errors you may find.", false)
	
	NewMessage()
	
	myMenu = scriptConfig("--[[ Zer0 Awareness ]]--", "ZAware")
	
	enemys = GetEnemyHeroes()
	
	GANKALERT_Menu()
end

function OnDraw()
	GANKALERT_Draw()
end

function OnTick()
	
end