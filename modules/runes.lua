local Runes = {}
local runeColors = {{r = 1, g = 0, b = 0.4}, {r = 0, g = 1, b = 0.4}, {r = 0, g = 0.4, b = 1}, {r = 0.7, g = 0.5, b = 1}}
ShadowUF:RegisterModule(Runes, "runeBar", ShadowUFLocals["Rune bar"], true)

function Runes:OnEnable(frame)
	if( select(2, UnitClass("player")) ~= "DEATHKNIGHT" ) then return end
			
	if( not frame.runeBar ) then
		frame.runeBar = CreateFrame("Frame", nil, frame)
		frame.runeBar:SetFrameLevel(frame.topFrameLevel)
		frame.runeBar.runes = {}
		
		for id=1, 6 do
			local rune = CreateFrame("StatusBar", frame.runeBar)
			rune:SetFrameLevel(frame.runeBar:GetFrameLevel() - 1)
			rune.id = id
			
			if( id > 1 ) then
				rune:SetPoint("TOPLEFT", frame.runeBar.runes[id - 1], "TOPRIGHT", 1, 0)
			else
				rune:SetPoint("TOPLEFT", frame.runeBar, "TOPLEFT", 0, 0)
			end
			
			frame.runeBar.runes[id] = rune
		end
	end
	
	frame:RegisterNormalEvent("RUNE_POWER_UPDATE", self, "UpdateUsable")
	frame:RegisterNormalEvent("RUNE_TYPE_UPDATE", self, "Update")
	frame:RegisterUpdateFunc(self, "Update")
	frame:RegisterUpdateFunc(self, "UpdateUsable")
end

function Runes:OnDisable(frame)
	frame:UnregisterAll(self)
end

function Runes:OnLayoutApplied(frame)
	if( frame.runeBar ) then
		local barWidth = (frame.runeBar:GetWidth() - 5 ) / 6
		
		for id, rune in pairs(frame.runeBar.runes) do
			rune:SetStatusBarTexture(ShadowUF.Layout.mediaPath.statusbar)
			rune:SetHeight(frame.runeBar:GetHeight())
			rune:SetWidth(barWidth)
		end
		
		self:Update(frame)
	end
end

local function runeMonitor(self, elapsed)
	local time = GetTime()
	self:SetValue(time)
	
	if( time >= self.endTime ) then
		self:SetValue(self.endTime)
		self:SetAlpha(1.0)
		self:SetScript("OnUpdate", nil)
	end
end

-- Updates the timers on runes
function Runes:UpdateUsable(frame, event, rune, available)
	for id, indicator in pairs(frame.runeBar.runes) do
		if( not rune or id == rune ) then
			local startTime, cooldown, cooled = GetRuneCooldown(id)
			if( not cooled ) then
				indicator.endTime = GetTime() + cooldown
				indicator:SetMinMaxValues(startTime, indicator.endTime)
				indicator:SetValue(GetTime())
				indicator:SetAlpha(0.50)
				indicator:SetScript("OnUpdate", runeMonitor)
			else
				indicator:SetMinMaxValues(0, 1)
				indicator:SetValue(1)
				indicator:SetAlpha(1.0)
				indicator:SetScript("OnUpdate", nil)
			end
		end
	end
end

-- No rune is passed for full update (Login), a single rune is passed when a single rune type changes, such as Blood Tap
function Runes:Update(frame, event, rune)
	for id, indicator in pairs(frame.runeBar.runes) do
		if( not rune or rune == id ) then
			local color = runeColors[GetRuneType(id)]
			indicator:SetStatusBarColor(color.r, color.g, color.b)
		end
	end
end
