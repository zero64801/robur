if Player.CharName ~= "Zilean" then return end

--//Variables-//--
local Zilean, Utils, Spell_Buffers = {}, {}, {}

local SDK = _G.CoreEx
local TS = _G.Libs.TargetSelector()

local ObjManager = SDK.ObjectManager
local EventManager = SDK.EventManager
local Renderer = SDK.Renderer
local Enums = SDK.Enums
local Game = SDK.Game

local Menu = Libs.NewMenu
local Orbwalker = Libs.Orbwalker
local HPPred = Libs.HealthPred
local Spell = Libs.Spell

local adcTable = { 
["Twitch"] = true, 
["Aphelios"] = true, 
["KogMaw"] = true, 
["Tristana"] = true, 
["Ashe"] = true, 
["Vayne"] = true, 
["Varus"] = true, 
["Xayah"] = true, 
["Lucian"] = true, 
["Sivir"] = true, 
["Draven"] = true, 
["Kalista"] = true, 
["Caitlyn"] = true, 
["Jinx"] = true, 
["Ezreal"] = true, 
["Samira"] = true,
["Senna"] = true,
["Jhin"] = true,
["Kindred"] = true,
["Kaisa"] = true,
["Corki"] = true,
["MissFortune"] = true
}

local spells = {
    Q = Spell.Skillshot({
        Slot = Enums.SpellSlots.Q,
        Delay = 0.75,
        Speed = math.huge,
        Range = 900,
        Radius = 130,
        Type = "Circular"
    }),
    W = Spell.Active({
        Slot            = Enums.SpellSlots.W
    }),
    E = Spell.Targeted({
        Slot            = Enums.SpellSlots.E,
		Range = 600
    }),
    R = Spell.Targeted({
        Slot            = Enums.SpellSlots.R,
        Range           = 900
    })
}

--//Library-//--
function Utils.SpellLocked()
    local buffers = 0
    for spell, time in pairs(Spell_Buffers) do
        buffers = buffers + 1
        if time - Game.GetTime() < 0 then 
            Spell_Buffers[spell] = nil
        end
    end
    return buffers == 0
end

function Utils.CastWithBuffer(Spell, Array)
	if Spell:Cast(unpack(Array)) then
		Spell_Buffers[Spell:GetName()] = Game.GetTime() + 1 -- Wait for Buffer
		return true
	end
end

function Utils.IsGameAvailable()
    return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead)
end

function Utils.GetMinions(Team, Range)
	local Table = {}
	for _,unit in ipairs(ObjManager.GetNearby(Team, "minions")) do
		local minion = unit.AsMinion
		if TS:IsValidTarget(unit) and unit.MaxHealth > 6 and unit.ServerPos:Distance(Player) <= Range then
			Table[#Table+1] = minion
		end		
	end
	return Table
end

function Utils.GetMinionsAndJungle(Range, GetAlly)
	local Table = {}
	
	local function AddtoTable(UnitTable)
		for _,unit in ipairs(UnitTable) do
			local minion = unit.AsMinion
			if TS:IsValidTarget(unit) and unit.MaxHealth > 6 and unit.ServerPos:Distance(Player) <= Range then
				Table[#Table+1] = minion
			end		
		end
	end	
	if GetAlly then
		AddtoTable(ObjManager.GetNearby("ally", "minions"))
	end
	AddtoTable(ObjManager.GetNearby("enemy", "minions"))
	AddtoTable(ObjManager.GetNearby("neutral", "minions"))
	
	return Table
end

function Utils.CountHeroesInRange(Team, Position, Range)
    local heroes = ObjManager.Get(Team, "heroes")
    local count = 0
    for _, hero in pairs(heroes) do
        if hero.IsValid and not hero.IsDead and hero.IsTargetable then
            if hero:Distance(Position) < Range then
                count = count + 1
            end
        end
    end
    return count
end


function Utils.HasBuffOfType(Source, Type)
	for _,Buff in pairs(Source.Buffs) do
		if Buff.BuffType == Type then
			return true
		end
	end
end

function Utils.GetEnemyHeroesInRange(Range, Pos)
	local h = {}
	local Pos = Pos or Player
    local Enemies = ObjManager.GetNearby("enemy", "heroes")
    for i = 1, #Enemies do
        local hero = Enemies[i]
        if hero.ServerPos:DistanceSqr(Pos) < Range * Range then
            h[#h + 1] = hero
        end
    end
    return h
end

function Zilean.Init()
	Zilean.LoadMenu()
	
    for EventName, EventId in pairs(Enums.Events) do
        if Zilean[EventName] then
            EventManager.RegisterCallback(EventId, Zilean[EventName])
        end
    end	
end

function Zilean.LoadMenu()
	Menu.RegisterMenu("FrostZilean", "Frost Zilean", function ()
		Menu.NewTree("Zilean.comboMenu", "Combo", function()
            Menu.Checkbox("Combo.UseQ", "Use Q", true)
			Menu.Dropdown("Chance.Q1", "[Q] HitChance", Enums.HitChance.Low, { "Collision", "OutOfRange", "VeryLow", "Low", "Medium", "High", "VeryHigh", "Dashing", "Immobile" })
            Menu.Checkbox("Combo.UseW", "Use W for Q Reset", true)
			Menu.Checkbox("Combo.whit", "Use W Only if Q Hits", false)
            Menu.Checkbox("Combo.UseE", "Use E", true)
			Menu.Checkbox("Combo.prioritye", "Use E First", false)
			Menu.NewTree("Zilean.rSettings", "R Settings", function()
			Menu.Checkbox("autor", "Auto R", true) 
			Menu.Slider("rhp", "Health % to use R", 25, 0, 100, 1)
				Menu.NewTree("Zilean.rSettings.whitelist", "Ally Settings", function()	
					for i, ally in pairs(ObjManager.Get("ally", "heroes")) do
						Menu.Checkbox("whitelist" .. ally.CharName, "Block: " .. ally.CharName, false)
					end
				end)
			end)
			Menu.Keybind("qwq", "Q-W-Q to Mouse", string.byte("G"), false, false, true)
		end)
		Menu.Separator()
		
		Menu.NewTree("Zilean.harassMenu", "Harass", function()
            Menu.Checkbox("Harass.UseQ", "Use Q", true)
            Menu.Checkbox("Harass.UseW", "Use W for Q Reset", true)
			Menu.Checkbox("Harass.whit", "Use W Only if Q Hits", false)
			Menu.Checkbox("Harass.UseE", "Use E", true)	
		end)
		Menu.Separator()
		
		Menu.NewTree("Zilean.weMenu", "W Boost Settings", function()
			Menu.Keybind("wekey", "W Boost Ally", string.byte("Z"), false, false, true)
			Menu.Text("0[Disabled] | 1[Highest Priority] | 5[Lowest Priority]")
			for i, ally in pairs(ObjManager.Get("ally", "heroes")) do
				Menu.Text("Priority: " .. ally.CharName)
				if not adcTable[ally.CharName] then
					Menu.Slider("we" .. ally.CharName, "", 0, 0, 5, 1)
				end
				if adcTable[ally.CharName] then
					Menu.Slider("we" .. ally.CharName, "", 1, 0, 5, 1)
				end
			end		
		end)
		Menu.Separator()
		
		Menu.NewTree("Zilean.drawingMenu", "Draw Settings", function()
            Menu.Checkbox("Drawing.Q", "Draw Q", true)
			Menu.Indent(function()
				Menu.ColorPicker("Drawing.QColor", "Color", 0xFF0000FF)
			end)
            Menu.Checkbox("Drawing.E", "Draw E", true)
			Menu.Indent(function()
				Menu.ColorPicker("Drawing.EColor", "Color", 0xFF0000FF)
			end)
			Menu.Checkbox("Drawing.R", "Draw R", true)
			Menu.Indent(function()
				Menu.ColorPicker("Drawing.RColor", "Color", 0xFF0000FF)
			end)
			Menu.Checkbox("Drawing.AlwaysDraw", "Always show Drawings", false)	
		end)
		Menu.Separator()		
		
		Menu.NewTree("Zilean.miscMenu", "Misc", function()
			Menu.Checkbox("Misc.autoe", "Auto E on Slowed Ally", true)	
			Menu.Checkbox("Misc.autoq", "Auto Q on Stun/Slow/Knockup", true)	
            Menu.Checkbox("Misc.AntiGapCloser", "Use E for Anti-Gapclose", true)
			Menu.NewTree("Zilean.Misc.AgBlacklist", "Anti-Gapclose Blacklist", function()
				for i, enemy in pairs(ObjManager.Get("enemy", "heroes")) do
					Menu.Checkbox("blacklist" .. enemy.CharName, "Block: " .. enemy.CharName, false)
				end			
			end)
		end)
		Menu.Separator()
		
		Menu.NewTree("Zilean.fleeMenu", "Flee", function()
			Menu.Keybind("Flee.fleekey", "Flee Key", string.byte("A"), false, false, true)
			Menu.Checkbox("Flee.fleew", " Use W for E Reset", false)		
		end)
		Menu.Separator()
	end)
end

function Zilean.PrioritizedAllyWE()
	local heroTarget = nil
	for i, ally in pairs(ObjManager.Get("ally", "heroes")) do
		if not Player.IsRecalling then
			if
				not ally.IsDead and Menu.Get("we" .. ally.CharName) > 0 and
					ally.ServerPos:Distance(Player) <= spells.E.Range
			then
				if heroTarget == nil then
					heroTarget = ally
				elseif Menu.Get("we" .. ally.CharName) < Menu.Get("we" .. heroTarget.CharName) then
					heroTarget = ally
				end
			end
		end
	end

	return heroTarget
end

function Zilean.AutoUnitQ2()
	local Minions = Utils.GetMinionsAndJungle(spells.Q.Range, true)
	for i, minion in pairs(Minions) do
		if minion:GetBuff("zileanqenemybomb") and #Utils.GetEnemyHeroesInRange(340, minion.ServerPos) > 0 then
			if not spells.Q:IsReady() and Player.Mana > spells.Q:GetManaCost() + spells.W:GetManaCost() then
				if spells.W:Cast() then
					return
				end
			end
			local Prediction = spells.Q:GetPrediction(minion)
			if Prediction then
				if Utils.CastWithBuffer(spells.Q, {Prediction.CastPosition}) then
					return
				end
			end
		end
	end
	
	for i, ally in ipairs(ObjManager.GetNearby("ally", "heroes")) do
		if ally:GetBuff("zileanqenemybomb") and #Utils.GetEnemyHeroesInRange(340, ally.ServerPos) > 0 then
			if not spells.Q:IsReady() and Player.Mana > spells.Q:GetManaCost() + spells.W:GetManaCost() then
				if spells.W:Cast() then
					return
				end
			end
			local Prediction = spells.Q:GetPrediction(ally)
			if Prediction then
				if Utils.CastWithBuffer(spells.Q, {Prediction.CastPosition}) then
					return
				end
			end
		end		
	end
end

function Zilean.AutoUlt()
	if spells.R:IsReady() and Menu.Get("autor") then
        local Allies = ObjManager.Get("ally", "heroes")
        for i, ally in pairs(Allies) do
			if ally ~= Player and not Menu.Get("whitelist" .. ally.CharName) then
				local HealthPred = HPPred.GetHealthPrediction(ally, 2, true)
				if (HealthPred / ally.MaxHealth) * 100 <= Menu.Get("rhp") and Utils.CountHeroesInRange("enemy", Player.ServerPos, 900) > 0 and ally.ServerPos:Distance(Player) <= spells.R.Range then
					if Utils.CastWithBuffer(spells.R, {ally}) then
						return
					end
				end
			end
		end
		if spells.R:IsReady() then
			if not Menu.Get("whitelist" .. Player.CharName) then
				local HealthPred = HPPred.GetHealthPrediction(Player, 2, true)
				if (HealthPred / Player.MaxHealth) * 100 <= Menu.Get("rhp") and Utils.CountHeroesInRange("enemy", Player.ServerPos, 650) > 0 then
					if Utils.CastWithBuffer(spells.R, {Player}) then
						return
					end
				end
			end			
		end
	end
end

function Zilean.OnGapclose(source, dashInstance)
	if spells.E:IsReady() and Menu.Get("Misc.AntiGapCloser", true) then
		if source.IsEnemy and not Menu.Get("blacklist" .. source.CharName) and Player.ServerPos:Distance(source) < spells.E.Range then
			Utils.CastWithBuffer(spells.E, {source})
		end
	end
end

function Zilean.Combo()
	local Target = TS:GetTarget(spells.Q.Range)
	if TS:IsValidTarget(Target) then
		if Menu.Get("Combo.prioritye") then
			if Menu.Get("Combo.UseE") and spells.E:IsReady() then
				if Target.ServerPos:Distance(Player) then
					if Utils.CastWithBuffer(spells.E, {Target}) then
						return
					end
				end
			end
			if Menu.Get("Combo.UseQ") and spells.Q:IsReady() then
				if Utils.SpellLocked() and Target.ServerPos:Distance(Player) <= spells.Q.Range then
					local Prediction = spells.Q:GetPrediction(Target)
					if Prediction and Prediction.HitChanceEnum >= Menu.Get("Chance.Q1") then
						if Utils.CastWithBuffer(spells.Q, {Prediction.CastPosition}) then
							return
						end
					end
				end
			end
			if Menu.Get("Combo.UseW") and Menu.Get("Combo.UseQ") then
				if Menu.Get("Combo.whit")  then
					if not spells.Q:IsReady() and Player.Mana > spells.Q:GetManaCost() + spells.W:GetManaCost() then
						if Target.ServerPos:Distance(Player) <= spells.Q.Range then
							if Target:GetBuff("zileanqenemybomb") then
								local Prediction = spells.Q:GetPrediction(Target)
								if Prediction then
									if spells.W:Cast() then
										return
									end
								end
							end
						end
					end
				else
					if not spells.Q:IsReady() and Player.Mana > spells.Q:GetManaCost() + spells.W:GetManaCost() then
						if Target.ServerPos:Distance(Player) <= spells.Q.Range then
							local Prediction = spells.Q:GetPrediction(Target)
							if Prediction then
								if spells.W:Cast() then
									return
								end
							end
						end
					end
				end
			end
		else
			if Menu.Get("Combo.UseE") and spells.E:IsReady() then
				if Target.ServerPos:Distance(Player) <= spells.E.Range then
					if Utils.CastWithBuffer(spells.E, {Target}) then
						return
					end
				end
			end
			if Menu.Get("Combo.UseQ") and spells.Q:IsReady() then
				if Utils.SpellLocked() and Target.ServerPos:Distance(Player) <= spells.Q.Range then
					local Prediction = spells.Q:GetPrediction(Target)
					if Prediction and Prediction.HitChanceEnum >= Menu.Get("Chance.Q1") then
						if Utils.CastWithBuffer(spells.Q, {Prediction.CastPosition}) then
							return
						end
					end
				end
			end
			if Menu.Get("Combo.UseW") and Menu.Get("Combo.UseQ") then
				if Menu.Get("Combo.whit") then
					if not spells.Q:IsReady() and Player.Mana > spells.Q:GetManaCost() + spells.W:GetManaCost() then
						if Target.ServerPos:Distance(Player) <= spells.Q.Range then
							if Target:GetBuff("zileanqenemybomb") then
								local Prediction = spells.Q:GetPrediction(Target)
								if Prediction then
									if spells.W:Cast() then
										return
									end
								end
							end
						end
					end
				else
					if not spells.Q:IsReady() and Player.Mana > spells.Q:GetManaCost() + spells.W:GetManaCost() then
						if Target.ServerPos:Distance(Player) <= spells.Q.Range then
							local Prediction = spells.Q:GetPrediction(Target)
							if Prediction then
								if spells.W:Cast() then
									return
								end
							end
						end
					end
				end
			end			
		end
	end
end

function Zilean.Harass()
	local Target = TS:GetTarget(spells.Q.Range)
	if TS:IsValidTarget(Target) then
		if Menu.Get("Harass.UseE") then
			if Target.ServerPos:Distance(Player) <= spells.E.Range then
				if Utils.CastWithBuffer(spells.E, {Target}) then
					return
				end
			end
		end
		if Menu.Get("Harass.UseQ") then
			if Utils.SpellLocked() and Target.ServerPos:Distance(Player) <= spells.Q.Range then
				local Prediction = spells.Q:GetPrediction(Target)
				if Prediction and Prediction.HitChanceEnum >= Enums.HitChance.Low then
					if Utils.CastWithBuffer(spells.Q, {Prediction.CastPosition}) then
						return
					end
				end
			end
		end
		if Menu.Get("Harass.UseW") then
			if Menu.Get("Harass.whit") then
				if not spells.Q:IsReady() and Player.Mana > spells.Q:GetManaCost() + spells.W:GetManaCost() then
					if Target.ServerPos:Distance(Player) <= spells.Q.Range then
						if Target:GetBuff("zileanqenemybomb") then
							local Prediction = spells.Q:GetPrediction(Target)
							if Prediction then
								if spells.W:Cast() then
									return
								end
							end
						end
					end
				end
			else
				if not spells.Q:IsReady() and Player.Mana > spells.Q:GetManaCost() + spells.W:GetManaCost() then
					if Target.ServerPos:Distance(Player) <= spells.Q.Range then
						local Prediction = spells.Q:GetPrediction(Target)
						if Prediction then
							if spells.W:Cast() then
								return
							end
						end
					end
				end			
			end
		end
	end
end

function Zilean.OnSpellCast(obj, spellcast)
    if spellcast.Source == Player and (spellcast.Slot == 0 or spellcast.Slot == 2 or spellcast.Slot == 3) then
		Spell_Buffers[spellcast.Name] = Game.GetTime() + spellcast.CastDelay + (Game.GetLatency() / 100) -- Added To buffer
    end
end

function Zilean.OnUpdate()
	if not Utils.IsGameAvailable() then
		return
	end

	Zilean.AutoUlt()
	Zilean.AutoUnitQ2()

	if Menu.Get("qwq") then
		local MousePos = Renderer.GetMousePos()
		if Utils.SpellLocked() then
			if spells.Q:IsReady() and Player.ServerPos:Distance(MousePos) < spells.Q.Range then
				if Utils.CastWithBuffer(spells.Q, {MousePos}) then
					return
				end
			end
		end
		if not spells.Q:IsReady() and Player.Mana > spells.Q:GetManaCost() + spells.W:GetManaCost() then
			if spells.W:Cast() then
				return
			end		
		end
	end

	if Menu.Get("Misc.autoe") and spells.E:IsReady() then
		for i, ally in ipairs(ObjManager.GetNearby("ally", "heroes")) do
			if Utils.HasBuffOfType(ally, Enums.BuffTypes.Slow) and ally.ServerPos:Distance(Player.ServerPos) <= spells.E.Range then
				if Utils.CastWithBuffer(spells.E, {ally}) then
					return
				end				
			end
		end
	end
	
	if Menu.Get("Misc.autoq") and spells.Q:IsReady() then
		for i, enemy in ipairs(ObjManager.GetNearby("enemy", "heroes")) do
			if enemy.ServerPos:Distance(Player) <= spells.Q.Range then
				if Utils.SpellLocked() and Utils.HasBuffOfType(enemy, Enums.BuffTypes.Slow) or Utils.HasBuffOfType(enemy, Enums.BuffTypes.Stun) or Utils.HasBuffOfType(enemy, Enums.BuffTypes.Knockup) then
					local Prediction = spells.Q:GetPrediction(enemy)
					if Prediction then
						if Utils.CastWithBuffer(spells.Q, {Prediction.CastPosition}) then
							return
						end
					end
				end
			end
		end
	end
	
	if Menu.Get("Flee.fleekey") then
		Orbwalker.Orbwalk(Renderer.GetMousePos(), nil)
		if Utils.CastWithBuffer(spells.E, {Player}) then
			fleetimeout = Game.GetTime() + 0.5
			return
		end
		if Menu.Get("Flee.fleew") and not Player:GetBuff("timewarp") and not spells.E:IsReady() and fleetimeout - Game.GetTime() < 0 then
			if spells.W:Cast() then
				return
			end
		end
	end
	
	if Menu.Get("wekey") then
		local Ally = Zilean.PrioritizedAllyWE()
		if Ally then
			if Utils.CastWithBuffer(spells.E, {Ally}) then
				return
			end
		end
	end
	
    local OrbwalkerState = Orbwalker.GetMode()
    if OrbwalkerState == "Combo" then
        Zilean.Combo()  
    elseif OrbwalkerState == "Harass" then
        Zilean.Harass()
    end
end

function Zilean.OnDraw()
    if (Menu.Get("Drawing.AlwaysDraw") or spells.Q:IsReady()) and Menu.Get("Drawing.Q") then
        Renderer.DrawCircle3D(Player.Position, spells.Q.Range, 30, 1, Menu.Get("Drawing.QColor"))
    end

    if (Menu.Get("Drawing.AlwaysDraw") or spells.E:IsReady()) and Menu.Get("Drawing.E") then
       Renderer.DrawCircle3D(Player.Position, spells.E.Range, 30, 1, Menu.Get("Drawing.EColor"))
    end	

    if (Menu.Get("Drawing.AlwaysDraw") or spells.R:IsReady()) and Menu.Get("Drawing.R") then
        Renderer.DrawCircle3D(Player.Position, spells.R.Range, 30, 1, Menu.Get("Drawing.RColor"))
    end	
end

Zilean.Init()