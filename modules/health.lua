local Health = {}
ShadowUF:RegisterModule(Health, "healthBar", ShadowUFLocals["Health bar"], true)

local function setGradient(healthBar, unit)
	local percent = UnitHealth(unit) / UnitHealthMax(unit)
	if( percent >= 1 ) then return Health:SetBarColor(healthBar, ShadowUF.db.profile.healthColors.green.r, ShadowUF.db.profile.healthColors.green.g, ShadowUF.db.profile.healthColors.green.b) end
	if( percent == 0 ) then return Health:SetBarColor(healthBar, ShadowUF.db.profile.healthColors.red.r, ShadowUF.db.profile.healthColors.red.g, ShadowUF.db.profile.healthColors.red.b) end
	
	local sR, sG, sB, eR, eG, eB, modifier, inverseModifier = 0, 0, 0, 0, 0, 0, percent * 2, 0
	if( percent > 0.50 ) then
		sR, sG, sB = ShadowUF.db.profile.healthColors.green.r, ShadowUF.db.profile.healthColors.green.g, ShadowUF.db.profile.healthColors.green.b
		eR, eG, eB = ShadowUF.db.profile.healthColors.yellow.r, ShadowUF.db.profile.healthColors.yellow.g, ShadowUF.db.profile.healthColors.yellow.b

		modifier = modifier - 1
		inverseModifier = 1 - modifier
	else
		sR, sG, sB = ShadowUF.db.profile.healthColors.yellow.r, ShadowUF.db.profile.healthColors.yellow.g, ShadowUF.db.profile.healthColors.yellow.b
		eR, eG, eB = ShadowUF.db.profile.healthColors.red.r, ShadowUF.db.profile.healthColors.red.g, ShadowUF.db.profile.healthColors.red.b
		inverseModifier = 1 - modifier
	end
	
	Health:SetBarColor(healthBar, eR * inverseModifier + sR * modifier, eG * inverseModifier + sG * modifier, eB * inverseModifier + sB * modifier)
end

-- Not doing full health update, because other checks can lag behind without much issue
local currentHealth
local function updateTimer(self)
	currentHealth = UnitHealth(self.parent.unit)
	if( currentHealth == self.currentHealth ) then return end
	self:SetValue(currentHealth)
		
	-- As much as I would rather not have to do this in an OnUpdate, I don't have much choice.
	-- large health changes in a single update will make them very clearly be lagging behind
	for _, fontString in pairs(self.parent.fontStrings) do
		if( fontString.fastHealth ) then
			fontString:UpdateTags()
		end
	end
	
	-- The target is not offline, and we have a health percentage so update the gradient
	if( not self.parent.healthBar.wasOffline and self.parent.healthBar.hasPercent ) then
		setGradient(self.parent.healthBar, self.parent.unit)
	end
end


function Health:OnEnable(frame)
	if( not frame.healthBar ) then
		frame.healthBar = ShadowUF.Units:CreateBar(frame)
	end
	
	frame:RegisterUnitEvent("UNIT_HEALTH", self, "Update")
	frame:RegisterUnitEvent("UNIT_MAXHEALTH", self, "Update")
	frame:RegisterUnitEvent("UNIT_FACTION", self, "UpdateColor")
	frame:RegisterUnitEvent("UNIT_THREAT_SITUATION_UPDATE", self, "UpdateThreat")
	
	frame:RegisterUpdateFunc(self, "UpdateColor")
	frame:RegisterUpdateFunc(self, "Update")
end

function Health:OnLayoutApplied(frame)
	if( frame.visibility.healthBar ) then
		if( ShadowUF.db.profile.units[frame.unitType].healthBar.predicted ) then
			frame.healthBar:SetScript("OnUpdate", updateTimer)
			frame.healthBar.parent = frame
		else
			frame.healthBar:SetScript("OnUpdate", nil)
		end
	end
end

function Health:OnDisable(frame)
	frame:UnregisterAll(self)
end

function Health:SetBarColor(bar, r, g, b)
	bar:SetStatusBarColor(r, g, b, ShadowUF.db.profile.bars.alpha)
	bar.background:SetVertexColor(r, g, b, ShadowUF.db.profile.bars.backgroundAlpha)
end

--[[
	WoWWIki docs on this are terrible, stole these from Omen
	
	nil = the unit is not on the mob's threat list
	0 = 0-99% raw threat percentage (no indicator shown)
	1 = 100% or more raw threat percentage (yellow warning indicator shown)
	2 = tanking, other has 100% or more raw threat percentage (orange indicator shown)
	3 = tanking, all others have less than 100% raw percentage threat (red indicator shown)
]]

local invalidUnit = {["partytarget"] = true, ["focustarget"] = true, ["targettarget"] = true, ["targettargettarget"] = true}
function Health:UpdateThreat(frame)
	if( not invalidUnit[frame.unitType] and ShadowUF.db.profile.units[frame.unitType].healthBar.colorAggro and UnitThreatSituation(frame.unit) == 3 ) then
		Health:SetBarColor(frame.healthBar, ShadowUF.db.profile.healthColors.red.r, ShadowUF.db.profile.healthColors.red.g, ShadowUF.db.profile.healthColors.red.b)
		frame.healthBar.hasAggro = true
	elseif( frame.healthBar.hasAggro ) then
		frame.healthBar.hasAggro = nil
		self:UpdateColor(frame)
	end
end

   
function Health:UpdateColor(frame)
	frame.healthBar.hasReaction = false
	frame.healthBar.hasPercent = false
	frame.healthBar.wasOffline = false

	-- Check aggro first, since it's going to override any other setting
	if( ShadowUF.db.profile.units[frame.unitType].healthBar.colorAggro ) then
		self:UpdateThreat(frame)
		if( frame.healthBar.hasAggro ) then return end
	end

	local color
	local unit = frame.unit
	if( not UnitIsConnected(unit) ) then
		frame.healthBar.wasOffline = true
		Health:SetBarColor(frame.healthBar, 0.50, 0.50, 0.50)
		return
	elseif( frame.inVehicle ) then
		color = ShadowUF.db.profile.classColors.VEHICLE
	elseif( not UnitIsTappedByPlayer(unit) and UnitIsTapped(unit) and UnitCanAttack("player", unit) ) then
		color = ShadowUF.db.profile.healthColors.tapped
	elseif( unit == "pet" and ShadowUF.db.profile.units[frame.unitType].healthBar.reaction and GetPetHappiness() ) then
		local happiness = GetPetHappiness()
		if( happiness == 3 ) then
			color = ShadowUF.db.profile.healthColors.friendly
		elseif( happiness == 2 ) then
			color = ShadowUF.db.profile.healthColors.neutral
		elseif( happiness == 1 ) then
			color = ShadowUF.db.profile.healthColors.hostile
		end
	-- Unit is not a player, or they are not a friend, but they aren't a player or pet the raid.
	elseif( ShadowUF.db.profile.units[frame.unitType].healthBar.reaction and ( ( not UnitIsPlayer(unit) or not UnitIsFriend(unit, "player") ) and ( not UnitPlayerOrPetInRaid(unit) and not UnitPlayerOrPetInParty(unit) ) ) ) then
		frame.healthBar.hasReaction = true
		if( not UnitIsFriend(unit, "player") and UnitPlayerControlled(unit) ) then
			if( UnitCanAttack("player", unit) ) then
				color = ShadowUF.db.profile.healthColors.hostile
			else
				color = ShadowUF.db.profile.healthColors.enemyUnattack
			end
		elseif( UnitReaction(unit, "player") ) then
			local reaction = UnitReaction(unit, "player")
			if( reaction > 4 ) then
				color = ShadowUF.db.profile.healthColors.friendly
			elseif( reaction == 4 ) then
				color = ShadowUF.db.profile.healthColors.neutral
			elseif( reaction < 4 ) then
				color = ShadowUF.db.profile.healthColors.hostile
			end
		end
	elseif( ShadowUF.db.profile.units[frame.unitType].healthBar.colorType == "class" and ( UnitIsPlayer(unit) or UnitCreatureFamily(unit) ) ) then
		if( UnitCreatureFamily(unit) ) then
			color = ShadowUF.db.profile.classColors.PET
		else
			local class = select(2, UnitClass(unit))
			if( class and ShadowUF.db.profile.classColors[class] ) then
				color = ShadowUF.db.profile.classColors[class]
			end
		end
	elseif( ShadowUF.db.profile.units[frame.unitType].healthBar.colorType == "static" ) then
		color = ShadowUF.db.profile.healthColors.green
	end
	
	if( color ) then
		Health:SetBarColor(frame.healthBar, color.r, color.g, color.b)
	else
		frame.healthBar.hasPercent = true
		setGradient(frame.healthBar, unit)
	end
end

function Health:Update(frame)
	local isOffline = not UnitIsConnected(frame.unit)

	frame.healthBar.currentHealth = UnitHealth(frame.unit)
	frame.healthBar:SetMinMaxValues(0, UnitHealthMax(frame.unit))
	frame.healthBar:SetValue(isOffline and UnitHealthMax(frame.unit) or UnitIsDeadOrGhost(frame.unit) and 0 or frame.healthBar.currentHealth)

	-- Next health update, hide the incoming heal when it was set to 0 health
	-- we do this to keep it all smooth looking as the heal done event comes 0.3s-0.5s before the health chang eevent
	if( frame.incHeal and frame.incHeal.nextUpdate ) then
		frame.incHeal:Hide()
	end
	
	-- Unit is offline, fill bar up + grey it
	if( isOffline ) then
		frame.healthBar.wasOffline = true
		Health:SetBarColor(frame.healthBar, 0.50, 0.50, 0.50)
	-- The unit was offline, but they no longer are so we need to do a forced color update
	elseif( frame.healthBar.wasOffline ) then
		frame.healthBar.wasOffline = false
		self:UpdateColor(frame)
	-- Color health by percentage
	elseif( frame.healthBar.hasPercent ) then
		setGradient(frame.healthBar, frame.unit)
	end
end
