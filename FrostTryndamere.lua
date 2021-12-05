if Player.CharName ~= "Tryndamere" then return end

--//Variables-//--
local Tryndamere, Utils, Spell_Buffers = {}, {}, {}

local SDK = _G.CoreEx
local TS = _G.Libs.TargetSelector()

local ObjManager = SDK.ObjectManager
local EventManager = SDK.EventManager
local Geometry = SDK.Geometry
local Renderer = SDK.Renderer
local Enums = SDK.Enums
local Game = SDK.Game
local Input = SDK.Input
local Evade = SDK.EvadeAPI

local Menu = Libs.NewMenu
local Orbwalker = Libs.Orbwalker
local HPPred = Libs.HealthPred
local Spell = Libs.Spell
local DmgLib = Libs.DamageLib

local spells = {
    Q = Spell.Active({
        Slot = Enums.SpellSlots.Q
    }),
    W = Spell.Targeted({
        Slot            = Enums.SpellSlots.W,
		Range = 850
    }),
    E = Spell.Skillshot({
        Slot            = Enums.SpellSlots.E,
        Delay = 0,
        Speed = 1300,
        Range = 600,
        Width = 225,
        Type = "Linear"
    }),
	EFarm = Spell.Skillshot({
        Slot = Enums.SpellSlots.E,
        Delay = 0,
        Speed = 1300,
        Range = 600,
		Radius = 225,
        Type = "Circular"
    }),
    R = Spell.Active({
        Slot            = Enums.SpellSlots.R
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
	if not Utils.SpellLocked() then
		return
	end
	if Spell:Cast(unpack(Array)) then
		Spell_Buffers[Spell:GetName()] = Game.GetTime() + 1 -- Wait for Buffer
		return true
	end
end

function Utils.IsGameAvailable()
    return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead)
end

function Utils.IsPosUnderTurret(pos)
    local enemyTurrets = ObjManager.GetNearby("enemy", "turrets")

    local boundingRadius = Player.BoundingRadius

    for _, obj in ipairs(enemyTurrets) do
        local turret = obj.AsTurret

        if turret and turret.IsValid and not turret.IsDead and pos:DistanceSqr(turret) <= math.pow(900 + boundingRadius, 2) then
            return true
        end
    end

    return false
end

function Utils.IsFacing(Source, Position)
	if Source == nil then
		return false
	end
	return Source.Direction:DotProduct((Position - Source.ServerPos)) > 0
end

function Utils.IsBothFacing(Source, Source2)
	if not Source or not Source2 then
		return false
	end
	return Utils.IsFacing(Source, Source2.ServerPos) and Utils.IsFacing(Source, Source2.ServerPos)
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

function Tryndamere.Init()
	Tryndamere.LoadMenu()
	
    for EventName, EventId in pairs(Enums.Events) do
        if Tryndamere[EventName] then
            EventManager.RegisterCallback(EventId, Tryndamere[EventName])
        end
    end	
end

function Tryndamere.LoadMenu()
	Menu.RegisterMenu("FrostTryndamere", "Frost Tryndamere", function ()
		Menu.NewTree("Tryndamere.comboMenu", "Combo", function()
            Menu.Checkbox("Combo.UseQ", "Use Q", true)
			Menu.Slider("qhp", "Health % to use Q", 25, 0, 100, 1)
            Menu.Checkbox("Combo.UseW", "Use W", true)
			Menu.Checkbox("Combo.ws", "W only if target facing", false)
            Menu.Checkbox("Combo.UseE", "Use E", true)
			Menu.Checkbox("Combo.UseR", "Use R", true)
			Menu.Slider("rhp", "Health % to use R", 25, 0, 100, 1)
			Menu.Separator()
			
			Menu.Keybind("Misc.SkillsUT", "Use Skills Under Turret", string.byte("T"), true, true, true)
		end)
		Menu.Separator()
		
		Menu.NewTree("Tryndamere.harassMenu", "Harass", function()
			Menu.Checkbox("Harass.UseE", "Use E", true)	
		end)
		Menu.Separator()

		Menu.NewTree("Tryndamere.clearMenu", "Clear", function()
			Menu.NewTree("Tryndamere.waveclearMenu", "WaveClear", function()
				Menu.Checkbox("Clear.UseE", "Use E", true)
				Menu.Checkbox("Clear.enemiesAround", "Don't clear if enemies around", true)
				Menu.Slider("Clear.xMinions", "if X Minions", 3, 1, 6, 1)
			end)
			Menu.NewTree("Tryndamere.jungleclearMenu", "JungleClear", function()
				Menu.Checkbox("JClear.UseE", "Use E", true)
				Menu.Slider("JClear.xMinions", "if X Minions", 2, 1, 6, 1)
			end)
		end)
		Menu.Separator()

		Menu.NewTree("Tryndamere.miscMenu", "Misc", function()
			Menu.Checkbox("Misc.eks", "Killsteal [E]", true)
			Menu.Keybind("Misc.fleekey", "Flee Key", string.byte("Z"), false, false, true)
            Menu.Checkbox("Misc.AntiGapCloser", "Use W for Anti-Gapclose", false)
			Menu.NewTree("Tryndamere.Misc.AgBlacklist", "Anti-Gapclose Blacklist", function()
				for i, enemy in pairs(ObjManager.Get("enemy", "heroes")) do
					Menu.Checkbox("blacklist" .. enemy.CharName, "Block: " .. enemy.CharName, false)
				end			
			end)
		end)
		Menu.Separator()
		
		Menu.NewTree("Tryndamere.drawingMenu", "Draw Settings", function()
            Menu.Checkbox("Drawing.W", "Draw W", true)
			Menu.Indent(function()
				Menu.ColorPicker("Drawing.WColor", "Color", 0xFF0000FF)
			end)
            Menu.Checkbox("Drawing.E", "Draw E", true)
			Menu.Indent(function()
				Menu.ColorPicker("Drawing.EColor", "Color", 0xFF0000FF)
			end)
			Menu.Checkbox("Drawing.AlwaysDraw", "Always show Drawings", false)	
		end)
		Menu.Separator()
		
        Menu.NewTree("Tryndamere.hcMenu", "Prediction", function()
			Menu.NewTree("Tryndamere.comboHcMenu", "Combo", function()
				Menu.Dropdown("Chance.E1", "[E] HitChance", Enums.HitChance.Low, { "Collision", "OutOfRange", "VeryLow", "Low", "Medium", "High", "VeryHigh", "Dashing", "Immobile" })
			end)
			Menu.NewTree("Tryndamere.harassHcMenu", "Harass", function()
				Menu.Dropdown("Chance.EH", "[E] HitChance", Enums.HitChance.Low, { "Collision", "OutOfRange", "VeryLow", "Low", "Medium", "High", "VeryHigh", "Dashing", "Immobile" })
			end)
        end)
	end)
end

function Tryndamere.EnemiesNearby()
    if Menu.Get("Clear.enemiesAround") and TS:GetTarget(1800) then
        return TS:GetTarget(1800)
    end
end

function Tryndamere.Killsteal()
	if Menu.Get("Misc.eks") and spells.E:IsReady() then
		for i, enemy in ipairs(ObjManager.GetNearby("enemy", "heroes")) do
			if not spells.E:IsReady() then
				break
			end
			if TS:IsValidTarget(enemy) and spells.E:GetDamage(enemy) > enemy.Health then
				local Prediction = spells.E:GetPrediction(enemy)
				if Utils.CastWithBuffer(spells.E, {Prediction.CastPosition}) then
					return
				end				
			end
		end
	end
end

function Tryndamere.AutoSaver()
	if Menu.Get("Combo.UseR") and spells.R:IsReady() then
		if not Player:GetBuff("chronoshift") then
			local HealthPred = HPPred.GetHealthPrediction(Player, 2, true)
			if (HealthPred / Player.MaxHealth) * 100 <= Menu.Get("rhp") and (Utils.CountHeroesInRange("enemy", Player.ServerPos, 650) > 0 or Orbwalker.HasTurretTargetting(Player) and Utils.IsPosUnderTurret(Player.ServerPos)) then
				if Utils.CastWithBuffer(spells.R, {}) then
					return
				end
			end
		end
	end
	if Menu.Get("Combo.UseQ") and spells.Q:IsReady() and not spells.R:IsReady() then
		if not Player:GetBuff("undyingrage") and not Player:GetBuff("chronoshift") then
			local HealthPred = HPPred.GetHealthPrediction(Player, 2, true)
			if (HealthPred / Player.MaxHealth) * 100 <= Menu.Get("qhp") or Player:GetBuff("zedr") then
				if Utils.CastWithBuffer(spells.Q, {}) then
					return
				end
			end		
		end
	end
end

function Tryndamere.OnGapclose(source, dashInstance)
	if spells.W:IsReady() and Menu.Get("Misc.AntiGapCloser", true) then
		if source.IsEnemy and not Menu.Get("blacklist" .. source.CharName) and spells.W.CanCast(spells.W,source) and Player.ServerPos:Distance(source) < spells.W.Range then
			Utils.CastWithBuffer(spells.W, {source})
		end
	end
end

function Tryndamere.Combo()
	local Target = TS:GetTarget(spells.W.Range)
	if TS:IsValidTarget(Target) and ((Menu.Get("Misc.SkillsUT") or Orbwalker.HasTurretTargetting(Player) and Utils.IsPosUnderTurret(Player.ServerPos)) or not Utils.IsPosUnderTurret(Target.ServerPos) ) then
		if Menu.Get("Combo.UseW") and spells.W:IsReady() then
			if Menu.Get("Combo.ws") and Utils.IsBothFacing(Player, Target) and Player.ServerPos:Distance(Target) > Orbwalker.GetTrueAutoAttackRange(Player, Target) + 30 then
				if spells.W.CanCast(spells.W,Target) and spells.W:Cast(Target) then
					return
				end
			end
			if spells.W:IsReady() and not Utils.IsFacing(Target, Player.ServerPos) and Player.ServerPos:Distance(Target) > Orbwalker.GetTrueAutoAttackRange(Player, Target) + 30 then
				if spells.W.CanCast(spells.W,Target) and spells.W:Cast(Target) then
					return
				end			
			end
		end
		
		if Menu.Get("Combo.UseE") and spells.E:IsReady() then
			local Prediction = spells.E:GetPrediction(Target)
			if Prediction and Prediction.HitChanceEnum >= Menu.Get("Chance.E1") and Player.ServerPos:Distance(Prediction.CastPosition) < spells.E.Range then
				if Utils.CastWithBuffer(spells.E, {Prediction.CastPosition}) then
					return
				end
			end
		end
	end
end

function Tryndamere.Harass()
	local Target = TS:GetTarget(spells.E.Range)
	if TS:IsValidTarget(Target) then
		if Menu.Get("Harass.UseE") and spells.E:IsReady() then
			local Prediction = spells.E:GetPrediction(Target)
			if Prediction and Prediction.HitChanceEnum >= Menu.Get("Chance.EH") then
				if Utils.CastWithBuffer(spells.E, {Prediction.CastPosition}) then
					return
				end
			end
		end
	end
end

function Tryndamere.Clear()
	if Menu.Get("JClear.UseE") and spells.E:IsReady() then
		local Minions = ObjManager.Get("neutral", "minions")
		local pos, n = spells.EFarm:GetBestCircularCastPos(Minions)
		if Utils.SpellLocked() then
			if n >= Menu.Get("JClear.xMinions") then
				if Utils.CastWithBuffer(spells.E, {pos}) then
					return
				end
			end
		end
	end

	if not Tryndamere.EnemiesNearby() then
		if Menu.Get("Clear.UseE") and spells.E:IsReady() then
			local Minions = ObjManager.Get("enemy", "minions")
			local pos, n = spells.EFarm:GetBestCircularCastPos(Minions)
			if Utils.SpellLocked() then
				if n >= Menu.Get("Clear.xMinions") then
					if Utils.CastWithBuffer(spells.E, {pos}) then
						return
					end
				end
			end
		end
	end
end

function Tryndamere.OnSpellCast(obj, spellcast)
    if spellcast.Source == Player and (spellcast.Slot == 1 or spellcast.Slot == 2) then
		Spell_Buffers[spellcast.Name] = Game.GetTime() + spellcast.CastDelay + (Game.GetLatency() / 100) -- Added To buffer
    end
end

function Tryndamere.OnTick()
	if not Utils.IsGameAvailable() then
		return
	end
	
	Tryndamere.AutoSaver()
	Tryndamere.Killsteal()
	
	if Menu.Get("Misc.fleekey") then
		local MousePos = Renderer.GetMousePos()
		Orbwalker.Orbwalk(MousePos, nil)
		if spells.E:IsReady() then
			local fleePos = Player.ServerPos:Extended(MousePos, spells.E.Range)
			if Utils.CastWithBuffer(spells.E, {fleePos}) then
				return
			end			
		end
	end
	
    local OrbwalkerState = Orbwalker.GetMode()
    if OrbwalkerState == "Combo" then
        Tryndamere.Combo()  
    elseif OrbwalkerState == "Harass" then
        Tryndamere.Harass()
	elseif OrbwalkerState == "Waveclear" then
		Tryndamere.Clear()
    end	
end

function Tryndamere.OnDraw()
	if Player.IsOnScreen == false then
		return
	end

    if (Menu.Get("Drawing.AlwaysDraw") or spells.W:IsReady()) and Menu.Get("Drawing.W") then
        Renderer.DrawCircle3D(Player.Position, spells.W.Range, 30, 1, Menu.Get("Drawing.WColor"))
    end

    if (Menu.Get("Drawing.AlwaysDraw") or spells.E:IsReady()) and Menu.Get("Drawing.E") then
       Renderer.DrawCircle3D(Player.Position, spells.E.Range, 30, 1, Menu.Get("Drawing.EColor"))
    end
	
	if not Menu.Get("Misc.SkillsUT") then
		Renderer.DrawTextOnPlayer("Q/R Under Turret [OFF]", 0xFF0000FF)
	else
		Renderer.DrawTextOnPlayer("Q/R Under Turret [ON]", 0x7FFFD4)
	end
end

Tryndamere.Init()