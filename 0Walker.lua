--[[
Name: 0Walker
By: AZer0

Please let me know of any errors you may find! This is in early beta still.

Requires: VPrediction

API:
_G.ZWalker:EnableAA()
_G.ZWalker:DisableAA()

_G.ZWalker:EnableMovement()
_G.ZWalker:DisableMovement()

_G.ZWalker:ForceTarget(target)
_G.ZWalker:ForcePoint(x, z)

_G.ZWalker:AddPreAttackCallBack(cb)
_G.ZWalker:AddAttackCallBack(cb)
_G.ZWalker:AddPostAttackCallBack(cb)

_G.ZWalker:GetOrbTarget()

_G.ZWalker:ActiveMode()

_G.ZWalker:IsLoaded()

_G.ZWalkerVer


To Do:
-Check for AA cancels
-Bonus Damage (Vayne Q, etc)
]]--

_G.ZWalkerVer = "1.04"
_G.ZWalker = nil

class("ZWalker")
function ZWalker:__init()
	self.VPred = nil
	self.TRPred = nil
	
	self.setup = {
		["Menu"] = false,
		["Pred"] = false
	}
	
	self.showMore = false
	if GetUser() == "AZer0" then
		self.showMore = true
	end
	
	self.projectileSpeed = 0
	self.baseWindUp = 3
	self.baseAnimation = 0.65
	self.trueRange = myHero.range + GetDistance(myHero.minBBox)
	self.lastAuto = 0
	self.lastAATick = 0
	self.lastWindTick = 3
	self.prevAttackTick = 0
	
	self.lastAACanceled = false
	self.lastAAChecking = false
	
	self.enemyMinions = minionManager(MINION_ENEMY, self.trueRange, myHero, MINION_SORT_MAXHEALTH_ASC)
	self.jungleMinions = minionManager(MINION_JUNGLE, self.trueRange, myHero, MINION_SORT_MAXHEALTH_DEC)
	self.champs = TargetSelector(TARGET_LESS_CAST_PRIORITY, self.trueRange, DAMAGE_PHYSICAL, true)
	
	self.lastMinion = nil
	
	self.ableTo = {
		["Attack"] = true,
		["Move"] = true
	}
	
	self.mode = nil
	self.target = nil
	self.forceTarget = nil
	self.forcePoint = nil
	
	self.menu = nil
	
	self.preAttackCB = {}
	self.attackCB = {}
	self.postAttackCB = {}
	
	self:AddMenu()
	self:AddPrediction()
	self:SetupTargeting()
	
	self:PrettyPrint("0 Walker - Version: " .. _G.ZWalkerVer .. ".", false)
	self:PrettyPrint("Please make detailed bug reports!", false)
end

function ZWalker:AddMenu()
	self.menu = scriptConfig("0 Walker", "ZeroWalker")
	
	self.menu:addParam("use", "Enable ZWalk", SCRIPT_PARAM_ONOFF, true)
	self.menu:addSubMenu(">> Fine Tune Settings <<", "FineTune")
		self.menu.FineTune:addParam("fDelay", "Farming Adjustment", SCRIPT_PARAM_SLICE, 0, -100, 100)
		self.menu.FineTune:addParam("eWindUp", "Wind Up Adjustment", SCRIPT_PARAM_SLICE, 0, -100, 100)
		self.menu.FineTune:addParam("mode", "Orbwalk Mode", SCRIPT_PARAM_LIST, 2, {"To Mouse", "To Target"})
		self.menu.FineTune:addParam("laneClear", "Lane Clear Mode", SCRIPT_PARAM_LIST, 2, {"Highest HP", "Keep Target"})
		self.menu.FineTune:addParam("canMode", "Timing Mode", SCRIPT_PARAM_LIST, 2, {"Method 1", "Method 2"})
		self.menu.FineTune:addParam("sticky", "Sticky Melee Kiting", SCRIPT_PARAM_ONOFF, true)
		self.menu.FineTune:addParam("aaResets", "Auto Register AA Resets", SCRIPT_PARAM_ONOFF, true)
		self.menu.FineTune:addParam("pred", "Prediction", SCRIPT_PARAM_LIST, 2, {"V Pred", "TR Pred"})
	
	self.menu:addSubMenu(">> Key Settings <<", "Keys")
		self.menu.Keys:addParam("carry", "Carry Mode", SCRIPT_PARAM_ONKEYDOWN, false, 32)
		self.menu.Keys:addParam("lane", "Lane Clear Mode", SCRIPT_PARAM_ONKEYDOWN, false, string.byte("V"))
		self.menu.Keys:addParam("harass", "Harass Mode", SCRIPT_PARAM_ONKEYDOWN, false, string.byte("C"))
		self.menu.Keys:addParam("last", "Last Hit Mode", SCRIPT_PARAM_ONKEYDOWN, false, string.byte("X"))
	
	self.menu:addSubMenu(">> Draw Settings <<", "Draw")
		self.menu.Draw:addParam("range", "AA Range", SCRIPT_PARAM_ONOFF, true)
	
	self.setup["Menu"] = true
end

function ZWalker:OrbWalk(target, point)
	if self.ableTo["Attack"] and self:AbleToAttack() and self:ValidTarget(target) and self:CBPreAttack(target) then
		self:Auto(target)
	elseif self.ableTo["Move"] and self:AbleToMove() then
		movePos = nil
		if self.menu.mode == 1 or not self.target then
			local toMouse = Vector(myHero) + 400 * (Vector(mousePos) - Vector(myHero)):normalized()
			movePos = {toMouse.x, toMouse.z}
		elseif self.menu.mode == 2 and self.target and GetDistanceSqr(self.target) <= self.trueRange * self.trueRange then
			local point = self:PredPosition(target, 0, 2 * myHero.ms, myHero, false)
			if GetDistanceSqr(point) < 100*100 + math.pow(self.VPred:GetHitBox(target), 2) then
				point = Vector(Vector(myHero) - point):normalized() * 50
			end
			movePos = {point.x, point.z}
		else
			local toMouse = Vector(myHero) + 400 * (Vector(mousePos) - Vector(myHero)):normalized()
			movePos = {toMouse.x, toMouse.z}
		end
		if movePos then
			self:MoveTo(movePos[1], movePos[2])
		end
	end
end

--API Functions
function ZWalker:EnableAA()
	self.ableTo["Attack"] = true
end

function ZWalker:DisableAA()
	self.ableTo["Attack"] = false
end

function ZWalker:EnableMovement()
	self.ableTo["Move"] = true
end

function ZWalker:DisableMovement()
	self.ableTo["Move"] = false
end

function ZWalker:ForceTarget(t)
	self.forceTarget = t
end

function ZWalker:ForcePoint(x, z)
	self.forcePoint = {x, z}
end

function ZWalker:AddPreAttackCallBack(cb)
	table.insert(self.preAttackCB, cb)
end

function ZWalker:AddAttackCallBack(cb)
	table.insert(self.attackCB, cb)
end

function ZWalker:AddPostAttackCallBack(cb)
	table.insert(self.postAttackCB, cb)
end

function ZWalker:GetOrbTarget()
	if self.forceTarget then return self.forceTarget end
	return self.target
end

function ZWalker:ActiveMode()
	return self.mode
end

function ZWalker:IsLoaded()
	if self.setup["Menu"] and self.setup["Pred"] then
		return true
	else
		return false
	end
end

--CallBack Functions
function ZWalker:CBPreAttack(t)
	local result = true
	for i, cb in ipairs(self.preAttackCB) do
		local ri = cb(t, self.mode)
		if not ri then
			result = false
		end
	end
	return result
end

function ZWalker:CBAttack(t)
	for i, cb in ipairs(self.attackCB) do
		cb(t, self.mode)
	end
end

function ZWalker:CBPostAttack(t)
	for i, cb in ipairs(self.postAttackCB) do
		cb(t, self.mode)
	end
end

--Misc Functions
function ZWalker:IsAuto(s)
	return (s:lower():find("attack"))
end

function ZWalker:IsAutoReset(u, s)
	local aaResets = {
		["Blitzcrank"] = {"PowerFist"},
		["Darius"] = {"DariusNoxianTacticsONH"},
		["Nidalee"] = {"Takedown"},
		["Sivir"] = {"Ricochet"},
		["Teemo"] = {"BlindingDart"},
		["Vayne"] = {"VayneTumble"},
		["Jax"] = {"JaxEmpowerTwo"},
		["Mordekaiser"] = {"MordekaiserMaceOfSpades"},
		["Nasus"] = {"SiphoningStrikeNew"},
		["Rengar"] = {"RengarQ"},
		["Wukong"] = {"MonkeyKingDoubleAttack"},
		["Yorick"] = {"YorickSpectral"},
		["Vi"] = {"ViE"},
		["Garen"] = {"GarenSlash3"},
		["Hecarim"] = {"HecarimRamp"},
		["XinZhao"] = {"XenZhaoComboTarget"},
		["Leona"] = {"LeonaShieldOfDaybreak"},
		["Shyvana"] = {"ShyvanaDoubleAttack", "shyvanadoubleattackdragon"},
		["Talon"] = {"TalonNoxianDiplomacy"},
		["Trundle"] = {"TrundleTrollSmash"},
		["Volibear"] = {"VolibearQ"},
		["Poppy"] = {"PoppyDevastatingBlow"}
	}
	
	if u and s and aaResets[u.charName] then
		for _, spell in pairs(aaResets[u.charName]) do
			if spell and spell == s then
				return true
			end
		end
	end
	return false
end

function ZWalker:PrettyPrint(message, isDebug)
	if isDebug and not self.showMore then return end
	if self.m == message then
		return
	end
	print("<font color=\"#FF5733\">[<b><i>0Walker</i></b>]</font> <font color=\"#3393FF\">" .. message .. "</font>")
	self.m = message
end

--Targeting Functions
function ZWalker:GetBestClearTarget()
	b = nil
	for i, minion in ipairs(self.enemyMinions.objects) do
		if minion and self:ValidMinion(minion) then
			if b == nil then
				b = minion
			elseif b.health < minion.health then
				b = minion
			end
		end
	end
	if not b then
		self.jungleMinions:update()
		for i, minion in ipairs(self.jungleMinions.objects) do
			if minion and self:ValidMinion(minion) then
				if b == nil then
					b = minion
				elseif b.health < minion.health then
					b = minion
				end
			end
		end
	end
	return b
end

function ZWalker:GetBestChampionTarget()
	if self.forceTarget and self:ValidChamp(self.forceTarget) and GetDistanceSqr(self.forceTarget) <= self.trueRange * self.trueRange then return self.forceTarget end
	if self.target and self:ValidChamp(self.target) and GetDistanceSqr(self.target) <= self.trueRange * self.trueRange then return self.target end
	if self.champs.target and self:ValidChamp(self.champs.target) and GetDistanceSqr(self.champs.target) <= self.trueRange * self.trueRange then return self.champs.target end
	return nil
end

function ZWalker:WaitForKillable()
	for i, minion in ipairs(self.enemyMinions.objects) do
		local time = self:AnimationTime() + GetDistance(minion.pos, myHero.pos) / self.projectileSpeed - 0.07
		if self:ValidMinion(minion) and self:PredHP(minion, time * 2.25, self.menu.FineTune.eWindUp / 1000) < self:GetDamage(minion, myHero, "AA") then
			return true
		end
	end
end

function ZWalker:CheckRange()
	tR = myHero.range + GetDistance(myHero.minBBox)
	if self.trueRange ~= tR then
		self.trueRange = tR
		self.enemyMinions.range = tR
		self.jungleMinions.range = tR
		self.champs.range = tR
	end
end

function ZWalker:GetKillableMinion()
	lowestMinion = nil
	lowestHP = nil
	for _, minion in pairs(self.enemyMinions.objects) do
		if minion and self:ValidMinion(minion) then
			local windDelay = self:WindUpTime(true) + GetDistance(minion.pos, myHero.pos) / self.projectileSpeed - 0.07
			local predHP = self:PredHP(minion, windDelay, self.menu.FineTune.eWindUp / 1000)
			print(predHP)
			if predHP < self:GetDamage(minion, myHero, "AA") - (self:GetDamage(minion, myHero, "AA") / 10) and predHP > -30 then
				if lowestMinion == nil then
					lowestMinion = minion
					lowestHP = predHP
				elseif lowestHP > predHP then
					lowestMinion = minion
					lowestHP = predHP
				end
			end
		end
	end
	if lowestMinion then
		return lowestMinion
	else
		return nil
	end
end

function ZWalker:SetupTargeting()
	self.priorityTable = {
		p5 = {"Alistar", "Amumu", "Blitzcrank", "Braum", "Dr. Mundo", "Garen", "Gnar", "Gragus", "Leona", "Mordekaiser", "Nautilus", "Olaf", "Poppy", "Rammus", "Rek'Sai", "Sejuani", "Shen", "Singed", "Sion", "Skarner", "Tahm Kench", "Taric", "Thresh", "Trundle", "Vi", "Volibear", "Warwick", "Wukong", "Zac"},
		p4 = {"Aatrox", "Camille", "Cho'Gath", "Darius", "Elise", "Galio", "Hecarim", "Illaoi", "Ivern", "Janna", "Jarvan IV", "Kayn", "Kled", "Lee Sin", "Malphite", "Maokai", "Nasus", "Nocturne", "Nunu", "Ornn", "Pantheon", "Rakan", "Renekton", "Shyvana", "Tryndamere", "Udyr", "Urgot", "Vladimir", "Yorick"},
		p3 = {"Akali", "Aurelion Sol", "Bard", "Ekko", "Evelynn", "Fiora", "Fizz", "Irelia", "Jax", "Karthus", "Kassadin", "Lissandra", "Morgana", "Nami", "Rengar", "Riven", "Rumble", "Shaco", "Sona", "Talon", "Teemo", "Twisted Fate", "Xin Zhao"},
		p2 = {"Ahri", "Anivia", "Annie", "Azir", "Brand", "Cassiopeia", "Corki", "Diana", "Fiddlesticks", "Gangplank", "Heimerdinger", "Jayce", "Karma", "Katarina", "Kayle", "Kennen", "Kha'Zix", "LeBlanc", "Lulu", "Lux", "Malzahar", "Nidalee", "Orianna", "Ryze", "Soraka", "Swain", "Syndra", "Taliyah", "Veigar", "Vel'Koz", "Viktor", "Yasuo", "Ziggs", "Zilean", "Zoe", "Zyra"},
		p1 = {"Ashe", "Caitlyn", "Draven", "Ezreal", "Graves", "Jhin", "Jinx", "Kalista", "Kindred", "Kog'Maw", "Lucian", "Master Yi", "Miss Fortune", "Quinn", "Sivir", "Tristana", "Twitch", "Varus", "Vayne", "Xayah", "Xerath", "Zed"}
	}
	
	local enemies = #GetEnemyHeroes()
    if enemies > 0 then
    	for i, enemy in ipairs(GetEnemyHeroes()) do
    	    self:SetPriority(self.priorityTable.p1, enemy, 1)
    	    self:SetPriority(self.priorityTable.p2, enemy, 2)
    	    self:SetPriority(self.priorityTable.p3, enemy, 3)
    	    self:SetPriority(self.priorityTable.p4, enemy, 4)
    	    self:SetPriority(self.priorityTable.p5, enemy, 5)
    	end
    end
end

function ZWalker:SetPriority(table, hero, priority)
	for i=1, #table, 1 do
        if hero.charName:find(table[i]) ~= nil then
            TS_SetHeroPriority(priority, hero.charName)
        end
    end
end

--Mode Functions
function ZWalker:LaneClear()
	local killMinion = self:GetKillableMinion()
	if killMinion then
		self:OrbWalk(killMinion)
	elseif not self:WaitForKillable() then
		m = self.lastMinion
		if self.menu.FineTune.laneClear == 1 or not self.lastMinion then
			m = self:GetBestClearTarget()
		end
		if m then
			self.lastMinion = m
			self:OrbWalk(m)
		else
			self:OrbWalk()
		end
	else
		self:OrbWalk()
	end
end

function ZWalker:Combo()
	local t = self.target
	if not t then
		t = self:GetBestChampionTarget()
	end
	
	if t then
		self:OrbWalk(t)
	else
		self:OrbWalk()
	end
end

function ZWalker:LastHit()
	local killMinion = self:GetKillableMinion()
	if killMinion then
		self:OrbWalk(killMinion)
	else
		self:OrbWalk()
	end
end

--Prediction Functions
function ZWalker:PredHP(m, t, d)
	if self.menu.FineTune.pred == 1 then
		return self.VPred:GetPredictedHealth(m, t, d)
	elseif self.menu.FineTune.pred == 2 then
		a, b, c, d = self.TRPred:GetMinionPrediction(m, t)
		return d
	end
end

function ZWalker:PredPosition(t, d, s, f)
	if self.menu.FineTune.pred == 1 then
		return self.VPred:GetPredictedPos(t, d, s, f, false)
	elseif self.menu.FineTune.pred == 2 then
		return self.TRPred:GetUnitPosition(t, d, true)
	end
end

function ZWalker:AddPrediction()
	if self.setup["Menu"] then
		if self.menu.FineTune.pred == 2 then
			require("TRPrediction")
			self.TRPred = TRPrediction()
		end
		require("VPrediction")
		self.VPred = VPrediction()
	else
		self:PrettyPrint("You must load the menu before adding predictions.")
	end
end

--Issue Cmd Function
function ZWalker:Auto(t)
	self.lastAuto = os.clock() + self:Latency()
	myHero:Attack(t)
end

function ZWalker:MoveTo(x, z)
	myHero:MoveTo(x, z)
end

--On Functions
function ZWalker:OnProcessSpell(u, s)
	if u and s and u.isMe and self:IsAuto(s.name) then
		self.baseAnimation = 1 / (s.animationTime * myHero.attackSpeed)
		self.baseWindUp = 1 / ((s.windUpTime * myHero.attackSpeed) * 1.3)
		self.lastAuto = os.clock() - self:Latency()
		
		self.lastWindTick = s.windUpTime*1000
		self.prevAttackTick = s.animationTime*1000
		self.lastAATick = GetTickCount() - GetLatency()/2
		
		self:CBAttack(s.target)
		DelayAction(function(t) self:CBPostAttack(t) end, self:WindUpTime() - self:Latency(), {s.target})
	elseif u and s and u.isMe and self:IsAutoReset(u, s.name) then
		self.lastAATick = 0
		self.lastAuto = 0
	end
end

function ZWalker:OnDraw()
	if self.menu.Draw.range then
		local p = WorldToScreen(D3DXVECTOR3(myHero.x, myHero.y, myHero.z))
		if OnScreen(p.x, p.y) then
			DrawCircle3D(myHero.x, myHero.y, myHero.z, self.trueRange, 1, ARGB(255, 255, 0, 0))
		end
	end
end

function ZWalker:OnTick()
	self:CheckRange()
	
	if self.menu.Keys.carry then
		mode = "Combo"
	elseif self.menu.Keys.harass then
		mode = "Harass"
	elseif self.menu.Keys.lane then
		mode = "LaneClear"
	elseif self.menu.Keys.last then
		mode = "LastHit"
	else
		mode = nil
	end
	
	if mode == "Combo" or mode == "Harass" then
		self.enemyMinions:update()
		self.champs:update()
		
		if self.forceTarget then
			self.target = self.forceTarget
		end
		
		if (not self.target and not self.forceTarget) or (self.target and not self:ValidChamp(self.target) and not self.forceTarget) then
			t = self:GetTarget()
			if t then self.target = t end
		end
		
		if mode == "Harass" then
			if self:LastHit() then
				return true
			end
		end
		self:Combo()
	elseif mode == "LaneClear" then
		self.enemyMinions:update()
		self.jungleMinions:update()
		if not self.lastMinion or not self:ValidMinion(self.lastMinion) or GetDistanceSqr(self.lastMinion) > self.trueRange * self.trueRange then
			self.lastMinion = nil
		end
		self:LaneClear()
	elseif mode == "LastHit" then
		self.enemyMinions:update()
		self:LastHit()
	end
end

--Target Functions
function ZWalker:ValidChamp(t)
	if ValidTarget(t) then return true end
	return false
end

function ZWalker:ValidMinion(t)
	if ValidTarget(t) then return true end
	return false
end

function ZWalker:ValidTarget(t)
	if ValidTarget(t) then return true end
	return false
end

function ZWalker:GetTarget()
	
end


--Timing Functions
function ZWalker:AbleToAttack()
	if self.menu.FineTune.canMode == 2 then
		return self:CanAutoTick()
	end
	
	if self.lastAuto <= os.clock() then
		return (os.clock() + self:Latency() > self.lastAuto + self:AnimationTime())
	end
	return false
end

function ZWalker:AbleToMove()
	if self.menu.FineTune.canMode == 2 then
		return self:CanMoveTick()
	end
	
	if self.lastAuto <= os.clock() then
		return (os.clock() + self:Latency() > self.lastAuto + self:WindUpTime() * 1.25)
	end
end

function ZWalker:Latency()
	return GetLatency() / 1500
end

function ZWalker:AnimationTime()
	return (1 / (myHero.attackSpeed * self.baseAnimation))
end

function ZWalker:CanMoveTick()
	return (GetTickCount() + GetLatency()/2 > self.lastAATick + self.lastWindTick + 20)
end

function ZWalker:CanAutoTick()
	return (GetTickCount() + GetLatency()/2 > self.lastAATick + self.prevAttackTick)
end

function ZWalker:WindUpTime(e)
	return (1 / (myHero.attackSpeed * self.baseWindUp)) + (e and 0 or self.menu.FineTune.eWindUp / 1000)
end

--Damage Functions
function ZWalker:MyDamage(t)
	myHero:CalcDamage(t, myHero.totalDamage)
end

function ZWalker:GetDamage(target, source, spell)
	lvl = source.level
	ad = source.totalDamage
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

--Updater Functions
function _ScriptUpdate:__init(tab)
    assert(tab and type(tab) == "table", "_ScriptUpdate: table is invalid!")
    self.LocalVersion = tab.LocalVersion
    assert(self.LocalVersion and type(self.LocalVersion) == "number", "_ScriptUpdate: LocalVersion is invalid!")
    local UseHttps = tab.UseHttps ~= nil and tab.UseHttps or true
    local VersionPath = tab.VersionPath
    assert(VersionPath and type(VersionPath) == "string", "_ScriptUpdate: VersionPath is invalid!")
    local ScriptPath = tab.ScriptPath
    assert(ScriptPath and type(ScriptPath) == "string", "_ScriptUpdate: ScriptPath is invalid!")
    local SavePath = tab.SavePath
    assert(SavePath and type(SavePath) == "string", "_ScriptUpdate: SavePath is invalid!")
    self.VersionPath = '/BoL/TCPUpdater/GetScript'..(UseHttps and '5' or '6')..'.php?script='..self:Base64Encode(VersionPath)..'&rand='..math.random(99999999)
    self.ScriptPath = '/BoL/TCPUpdater/GetScript'..(UseHttps and '5' or '6')..'.php?script='..self:Base64Encode(ScriptPath)..'&rand='..math.random(99999999)
    self.SavePath = SavePath
    self.CallbackUpdate = tab.CallbackUpdate
    self.CallbackNoUpdate = tab.CallbackNoUpdate
    self.CallbackNewVersion = tab.CallbackNewVersion
    self.CallbackError = tab.CallbackError
    --AddDrawCallback(function() self:OnDraw() end)
    self:CreateSocket(self.VersionPath)
    self.DownloadStatus = 'Connect to Server for VersionInfo'
    AddTickCallback(function() self:GetOnlineVersion() end)
end

function _ScriptUpdate:print(str)
    print('<font color="#FFFFFF">'..os.clock()..': '..str)
end

function _ScriptUpdate:OnDraw()
    if self.DownloadStatus ~= 'Downloading Script (100%)' then
    end
end

function _ScriptUpdate:CreateSocket(url)
    if not self.LuaSocket then
        self.LuaSocket = require("socket")
    else
        self.Socket:close()
        self.Socket = nil
        self.Size = nil
        self.RecvStarted = false
    end
    self.Socket = self.LuaSocket.tcp()
    if not self.Socket then
        print('Socket Error')
    else
        self.Socket:settimeout(0, 'b')
        self.Socket:settimeout(99999999, 't')
        self.Socket:connect('sx-bol.eu', 80)
        self.Url = url
        self.Started = false
        self.LastPrint = ""
        self.File = ""
    end
end

function _ScriptUpdate:Base64Encode(data)
    local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    return ((data:gsub('.', function(x)
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

function _ScriptUpdate:GetOnlineVersion()
    if self.GotScriptVersion then return end

    self.Receive, self.Status, self.Snipped = self.Socket:receive(1024)
    if self.Status == 'timeout' and not self.Started then
        self.Started = true
        self.Socket:send("GET "..self.Url.." HTTP/1.1\r\nHost: sx-bol.eu\r\n\r\n")
    end
    if (self.Receive or (#self.Snipped > 0)) and not self.RecvStarted then
        self.RecvStarted = true
        self.DownloadStatus = 'Downloading VersionInfo (0%)'
    end

    self.File = self.File .. (self.Receive or self.Snipped)
    if self.File:find('</s'..'ize>') then
        if not self.Size then
            self.Size = tonumber(self.File:sub(self.File:find('<si'..'ze>')+6,self.File:find('</si'..'ze>')-1))
        end
        if self.File:find('<scr'..'ipt>') then
            local _,ScriptFind = self.File:find('<scr'..'ipt>')
            local ScriptEnd = self.File:find('</scr'..'ipt>')
            if ScriptEnd then ScriptEnd = ScriptEnd - 1 end
            local DownloadedSize = self.File:sub(ScriptFind+1,ScriptEnd or -1):len()
            self.DownloadStatus = 'Downloading VersionInfo ('..math.round(100/self.Size*DownloadedSize,2)..'%)'
        end
    end
    if self.File:find('</scr'..'ipt>') then
        self.DownloadStatus = 'Downloading VersionInfo (100%)'
        local a,b = self.File:find('\r\n\r\n')
        self.File = self.File:sub(a,-1)
        self.NewFile = ''
        for line,content in ipairs(self.File:split('\n')) do
            if content:len() > 5 then
                self.NewFile = self.NewFile .. content
            end
        end
        local HeaderEnd, ContentStart = self.File:find('<scr'..'ipt>')
        local ContentEnd, _ = self.File:find('</sc'..'ript>')
        if not ContentStart or not ContentEnd then
            if self.CallbackError and type(self.CallbackError) == 'function' then
                self.CallbackError()
            end
        else
            self.OnlineVersion = (Base64Decode(self.File:sub(ContentStart + 1,ContentEnd-1)))
            if self.OnlineVersion ~= nil then
                self.OnlineVersion = tonumber(self.OnlineVersion)
                if self.OnlineVersion ~= nil and self.LocalVersion ~= nil and type(self.OnlineVersion) == "number" and type(self.LocalVersion) == "number" and self.OnlineVersion > self.LocalVersion then
                    if self.CallbackNewVersion and type(self.CallbackNewVersion) == 'function' then
                        self.CallbackNewVersion(self.OnlineVersion,self.LocalVersion)
                    end
                    self:CreateSocket(self.ScriptPath)
                    self.DownloadStatus = 'Connect to Server for ScriptDownload'
                    AddTickCallback(function() self:DownloadUpdate() end)
                else
                    if self.CallbackNoUpdate and type(self.CallbackNoUpdate) == 'function' then
                        self.CallbackNoUpdate(self.LocalVersion)
                    end
                end
            end
        end
        self.GotScriptVersion = true
    end
end

function _ScriptUpdate:DownloadUpdate()
    if self.GotScriptUpdate then return end
    self.Receive, self.Status, self.Snipped = self.Socket:receive(1024)
    if self.Status == 'timeout' and not self.Started then
        self.Started = true
        self.Socket:send("GET "..self.Url.." HTTP/1.1\r\nHost: sx-bol.eu\r\n\r\n")
    end
    if (self.Receive or (#self.Snipped > 0)) and not self.RecvStarted then
        self.RecvStarted = true
        self.DownloadStatus = 'Downloading Script (0%)'
    end

    self.File = self.File .. (self.Receive or self.Snipped)
    if self.File:find('</si'..'ze>') then
        if not self.Size then
            self.Size = tonumber(self.File:sub(self.File:find('<si'..'ze>')+6,self.File:find('</si'..'ze>')-1))
        end
        if self.File:find('<scr'..'ipt>') then
            local _,ScriptFind = self.File:find('<scr'..'ipt>')
            local ScriptEnd = self.File:find('</scr'..'ipt>')
            if ScriptEnd then ScriptEnd = ScriptEnd - 1 end
            local DownloadedSize = self.File:sub(ScriptFind+1,ScriptEnd or -1):len()
            self.DownloadStatus = 'Downloading Script ('..math.round(100/self.Size*DownloadedSize,2)..'%)'
        end
    end
    if self.File:find('</scr'..'ipt>') then
        self.DownloadStatus = 'Downloading Script (100%)'
        local a,b = self.File:find('\r\n\r\n')
        self.File = self.File:sub(a,-1)
        self.NewFile = ''
        for line,content in ipairs(self.File:split('\n')) do
            if content:len() > 5 then
                self.NewFile = self.NewFile .. content
            end
        end
        local HeaderEnd, ContentStart = self.NewFile:find('<sc'..'ript>')
        local ContentEnd, _ = self.NewFile:find('</scr'..'ipt>')
        if not ContentStart or not ContentEnd then
            if self.CallbackError and type(self.CallbackError) == 'function' then
                self.CallbackError()
            end
        else
            local newf = self.NewFile:sub(ContentStart+1,ContentEnd-1)
            local newf = newf:gsub('\r','')
            if newf:len() ~= self.Size then
                if self.CallbackError and type(self.CallbackError) == 'function' then
                    self.CallbackError()
                end
                return
            end
            local newf = Base64Decode(newf)
            if type(load(newf)) ~= 'function' then
                if self.CallbackError and type(self.CallbackError) == 'function' then
                    self.CallbackError()
                end
            else
                local f = io.open(self.SavePath,"w+b")
                f:write(newf)
                f:close()
                if self.CallbackUpdate and type(self.CallbackUpdate) == 'function' then
                    self.CallbackUpdate(self.OnlineVersion,self.LocalVersion)
                end
            end
        end
        self.GotScriptUpdate = true
    end
end

function CheckUpdates()
	local ToUpdate = {}
	ToUpdate.LocalVersion = _G.ZWalkerVer
	ToUpdate.VersionPath = "raw.githubusercontent.com/azero/BoL/LeagueBoL/version/0Walker.version"
	ToUpdate.ScriptPath = "raw.githubusercontent.com/azero/BoL/LeagueBoL/0Walker.lua"
	ToUpdate.SavePath = LIB_PATH .. "0Walker.lua"
	ToUpdate.CallbackUpdate = function(NewVersion,OldVersion) PrintMessage("Updated from " .. _G.ZWalkerVer .. " to " .. NewVersion .. ". Please reload with 2x F9.") end
	ToUpdate.CallbackNoUpdate = function(OldVersion) PrintMessage("No Updates Found.") end
	ToUpdate.CallbackNewVersion = function(NewVersion) PrintMessage("New Version found (" .. NewVersion .. "). Please wait...") end
	ToUpdate.CallbackError = function(NewVersion) PrintMessage("Error while trying to check update.") end
	_ScriptUpdate(ToUpdate)
end

--BoL On Function
function OnLoad()
	CheckUpdates()
	_G.ZWalker = ZWalker()
end

function OnDraw()
	if _G.ZWalker then _G.ZWalker:OnDraw() end
end

function OnTick()
	if _G.ZWalker then _G.ZWalker:OnTick() end
end

function OnProcessAttack(u, s)
	if _G.ZWalker then _G.ZWalker:OnProcessSpell(u, s) end
end

function OnProcessSpell(u, s)
	if _G.ZWalker then _G.ZWalker:OnProcessSpell(u, s) end
end