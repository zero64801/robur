if Player.CharName ~= "Vi" then return end

--//Variables-//--
local Vi = {}

local SDK = _G.CoreEx
local TS = _G.Libs.TargetSelector()

local ObjManager = SDK.ObjectManager
local EventManager = SDK.EventManager
local Geometry = SDK.Geometry
local Renderer = SDK.Renderer
local Enums = SDK.Enums
local Input = SDK.Input

local Menu = Libs.NewMenu
local Orbwalker = Libs.Orbwalker
local Spell = Libs.Spell
local DmgLib = Libs.DamageLib

local spells = {
    Q = Spell.Chargeable({
        Slot = Enums.SpellSlots.Q,
        Delay = 0.5,
        Speed = 1250,
		MinRange = 250,
        MaxRange = 725,
        FullChargeTime = 1.25,
        Collisions = {Heroes = false, Minions = false, WindWall = false},
        Type = "Linear",
    }),
    W = Spell.Active({
        Slot            = Enums.SpellSlots.W
    }),
    E = Spell.Active({
        Slot            = Enums.SpellSlots.E
    }),
    R = Spell.Targeted({
        Slot            = Enums.SpellSlots.R,
        Range           = 800
    }),
    Flash = {
        Slot = nil,
        LastCastT = 0,
        LastCheckT = 0,
        Range = 400,
    }
}

--//Library-//--
local summSlots = {Enums.SpellSlots.Summoner1, Enums.SpellSlots.Summoner2}
function GetSpellSlot(Name)
    for _, slot in ipairs(summSlots) do
        if Player:GetSpell(slot).Name == Name then
            return slot
        end
    end	
end
spells.Flash.Slot = GetSpellSlot("SummonerFlash")

function GetMinions(team, range)
	local Table = {}
	for _,unit in ipairs(ObjManager.GetNearby(team, "minions")) do
		local minion = unit.AsMinion
		if TS:IsValidTarget(unit) and unit.MaxHealth > 6 and unit.ServerPos:Distance(Player.ServerPos) <= range then
			Table[#Table+1] = minion
		end		
	end
	return Table
end

function IsPosUnderTurret(pos)
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

function Vi.Init()
	Vi.LoadMenu()
	
    for EventName, EventId in pairs(Enums.Events) do
        if Vi[EventName] then
            EventManager.RegisterCallback(EventId, Vi[EventName])
        end
    end	
end

function Vi.LoadMenu()
	Menu.RegisterMenu("FrostVi", "Frost Vi", function ()
		Menu.ColumnLayout("cols", "cols", 4, true, function()
            Menu.ColoredText("Combo", 0x9400D3, true)
            Menu.Checkbox("Combo.UseQ", "Use Q", true) 
			Menu.Dropdown("Combo.QMode", "Q Mode", 0, {"Logic", "MaxRange"})
			Menu.Slider("Chance.Q","HitChance [Q]", 0.75, 0, 1, 0.05)
            Menu.Checkbox("Combo.UseE", "Use E", true)  
            Menu.Checkbox("Combo.UseR", "Use R", true)
			Menu.Dropdown("Combo.RMode", "R Mode", 0, {"Killable", "Always"})
			--Menu.Keybind("Combo.Flash", "Flash Q", string.byte("G"), false, false, true)
			
			Menu.NextColumn()
			
			Menu.ColoredText("Harass", 0x9400D3, true)
            Menu.Checkbox("Harass.UseQ", "Use Q", true)
            Menu.Checkbox("Harass.UseE", "Use E", true)
			
			Menu.NextColumn()
			
			Menu.ColoredText("Clear", 0x9400D3, true)
            Menu.Checkbox("Clear.UseQ", "Use Q", true)
            Menu.Checkbox("Clear.UseE", "Use E", true)
            Menu.Checkbox("JClear.UseQ", "Use Q Jungle", true)
            Menu.Checkbox("JClear.UseE", "Use E Jungle", true)
			Menu.Checkbox("Clear.enemiesAround", "Don't clear if enemies around", true)
			Menu.Slider("Clear.ManaSlider", "Don't Clear if Mana < %", 50, 1, 100, 1)
			
			Menu.NextColumn()
			
			Menu.ColoredText("Misc", 0x9400D3, true)
            Menu.Checkbox("Drawing.Q", "Draw Q", true)
			Menu.Checkbox("Drawing.R", "Draw R", true)
            Menu.Checkbox("Misc.AntiGapCloser", "Use AntiGapCloser", true)
            Menu.Checkbox("Misc.Interrupt", "Use Interrupt", true)	
			Menu.Keybind("Misc.SkillsUT", "Use Skills Under Turret", string.byte("T"), true, false, true)
		end)
	end)
end

function Vi.EnemiesNearby()
    if Menu.Get("Clear.enemiesAround") and TS:GetTarget(1800) then
        return TS:GetTarget(1800)
    end
end

function Vi.ComboDamage(Target)
	local Damage = 0
	if spells.Q:IsReady() then
		Damage = Damage + spells.Q:GetDamage(Target)
	end
	if spells.E:IsReady() then
		Damage = Damage + ((spells.E:GetDamage(Target) * spells.E:GetCurrentAmmo()) + DmgLib:GetAutoAttackDamage(Player, Target, true))
	end
	if spells.R:IsReady() then
		Damage = Damage + spells.R:GetDamage(Target)
	end
	return Damage
end

function Vi.flashQ()
	if Menu.Get("Combo.Flash") then
		Orbwalker.Orbwalk(Renderer.GetMousePos(), nil)
		local Target = TS:GetTarget(spells.Q.MaxRange)
		if TS:IsValidTarget(Target) then
			local CanFlash = spells.Flash.Slot and Player:GetSpellState(spells.Flash.Slot) == Enums.SpellStates.Ready
			if CanFlash then
				local CastPos = spells.Q:GetPrediction(Target)
				if CastPos then
					CastPos = CastPos.CastPosition
					if spells.Q:IsReady() then
						if not spells.Q.IsCharging then
							spells.Q:StartCharging()
						else
							if spells.Q:GetRange() == spells.Q.MaxRange then
								local FlashPosition = Player.ServerPos:Extended(CastPos, 400)
								if spells.Q:Release(Target.ServerPos) then
									delay(70, function() Input.Cast(spells.Flash.Slot, FlashPosition) end)
								end
							end
						end
					end
				end
			end
		end
	end
end

function Vi.OnInterruptibleSpell(source, spellCast, danger, endTime, canMoveDuringChannel)
	if Menu.Get("Misc.Interrupt", true) then
		if danger >= 3 then
			if spells.Q:IsReady() and Player.ServerPos:Distance(source) < spells.Q.MinRange then
				if not spells.Q.IsCharging then
					spells.Q:StartCharging()
				else		
					spells.Q:Release(source)
				end
			else
				if spells.R:CanCast(source) then
					spells.R:Cast(source)
				end
			end	
		end
	end
end

function Vi.OnGapclose(source)
	if Menu.Get("Misc.AntiGapCloser", true) then
		if spells.Q:IsReady() and Player.ServerPos:Distance(source) < spells.Q.MinRange then
			if not spells.Q.IsCharging then
				spells.Q:StartCharging()
			else		
				spells.Q:Release(source)
			end
		end
	end
end

function Vi.Combo()
	local Target = TS:GetTarget(spells.Q.MaxRange)
	if TS:IsValidTarget(Target) and ((Menu.Get("Misc.SkillsUT") or Orbwalker.HasTurretTargetting(Player) and IsPosUnderTurret(Player.ServerPos)) or not IsPosUnderTurret(Target.ServerPos) ) then
		if Menu.Get("Combo.UseQ", true) and spells.Q:IsReady() then
			if spells.Q.IsCharging then
				local Prediction = spells.Q:GetPrediction(Target)
				if spells.Q:GetRange() == spells.Q.MaxRange or Menu.Get("Combo.QMode") == 0 and Orbwalker.GetTrueAutoAttackRange(Player) >= Player:Distance(Target) then
					if Prediction and spells.Q:ReleaseOnHitChance(Prediction.CastPosition, Menu.Get("Chance.Q")) then
						return
					end
				end
			else
				spells.Q:StartCharging()
			end
		end
		
		if Menu.Get("Combo.UseR", true) and spells.R:IsReady() and TS:IsValidTarget(Target, spells.R.Range) then
			local RTargets = spells.R:GetTargets()
			table.sort(RTargets, function(a, b)
				return a.Health < b.Health
			end)
			if Menu.Get("Combo.RMode") == 0 then
				for _,enemy in ipairs(RTargets) do
					if Vi.ComboDamage(enemy) > enemy.Health then
						spells.R:Cast(enemy)
						break
					end
				end
			else
				spells.R:Cast(RTargets[1])
			end
		end
	end
end

function Vi.Harass()
	local Target = TS:GetTarget(spells.Q.MaxRange)
	if TS:IsValidTarget(Target) then
		if Menu.Get("Harass.UseQ", true) and spells.Q:IsReady() then
			if spells.Q.IsCharging then
				spells.Q:Release(Target)
			else
				spells.Q:StartCharging()
			end
		end

		if Menu.Get("Harass.UseE", true) and spells.E:IsReady() then
			spells.E:Cast()
		end
	end
end

function Vi.Clear()
	Vi.LaneClear()
	Vi.JungleClear()
end

function Vi.LaneClear()
	if Vi.EnemiesNearby() then return end
	if Player.ManaPercent * 100 > Menu.Get("Clear.ManaSlider") then
		local Minions = GetMinions("enemy", spells.Q.MaxRange)
		if Minions and #Minions > 1 then
			if Menu.Get("Clear.UseQ") and spells.Q:IsReady() then
				local minionsPositions = {}

				for _, minion in ipairs(Minions) do
					table.insert(minionsPositions, minion.Position)
				end
						
				local bestPos, numberOfHits = Geometry.BestCoveringRectangle(minionsPositions, Player.Position, 65) 
				if bestPos:IsValid() and numberOfHits > 2 then		
					if not spells.Q.IsCharging then
						spells.Q:StartCharging()
					else
						spells.Q:Release(bestPos)			
					end
				end
			end
		end
	end
end

function Vi.JungleClear()
    if Vi.EnemiesNearby() then return end
	if Player.ManaPercent * 100 > Menu.Get("Clear.ManaSlider") then
		local Minions = GetMinions("neutral", spells.E.Range)
		if Minions and #Minions > 0 then
			if Menu.Get("Clear.UseQ") and spells.Q:IsReady() then
				local minionsPositions = {}

				for _, minion in ipairs(Minions) do
					table.insert(minionsPositions, minion.Position)
				end
						
				local bestPos, numberOfHits = Geometry.BestCoveringRectangle(minionsPositions, Player.Position, 65) 
				if bestPos:IsValid() and numberOfHits > 1 then		
					if not spells.Q.IsCharging then
						spells.Q:StartCharging()
					else
						spells.Q:Release(bestPos)			
					end
				end
			end
		end
	end	
end

function Vi.OnUpdate() 
    local OrbwalkerState = Orbwalker.GetMode()
    if OrbwalkerState == "Combo" then
        Vi.Combo()  
    elseif OrbwalkerState == "Harass" then
        Vi.Harass()
    elseif OrbwalkerState == "Waveclear" then
       Vi.Clear()
    end
	--Vi.flashQ()
end

function Vi.OnPostAttack()
	if Orbwalker.GetMode() == "Combo" then
		if Menu.Get("Combo.UseE", true) and spells.E:IsReady() then
			spells.E:Cast()
			Orbwalker:ResetAttack()
		end
	elseif Orbwalker.GetMode() == "Waveclear" then
		if Vi.EnemiesNearby() then return end
		if (Menu.Get("Clear.UseE", true) or Menu.Get("JClear.UseE", true)) and spells.E:IsReady() then
			spells.E:Cast()
			Orbwalker:ResetAttack()
		end	
	end
end

function Vi.OnDraw()
    if Menu.Get("Drawing.Q") then
        Renderer.DrawCircle3D(Player.Position, spells.Q.MaxRange, 30, 1, 0x8400D7)
    end

    if Menu.Get("Drawing.R") then
        Renderer.DrawCircle3D(Player.Position, spells.R.Range, 30, 1, 0x8400D7)
    end	
	
	if not Menu.Get("Misc.SkillsUT") then
		Renderer.DrawTextOnPlayer("Q/R Under Turret [OFF]", 0xFF0000FF)
	else
		Renderer.DrawTextOnPlayer("Q/R Under Turret [ON]", 0x7FFFD4)
	end
end

function Vi.OnDrawDamage(Target, dmgList)
    table.insert(dmgList, Vi.ComboDamage(Target))
end

Vi.Init()