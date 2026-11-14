--!nonstrict
-- Погода на клиенте: дождь, снег, туман, гроза. Частицы летят вокруг камеры,
-- а под крышей дождь и снег выключаются, чтобы в помещении было сухо

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Workshop"):WaitForChild("Shared")
local Format = require(Shared.Format)

local WeatherFx = {}
WeatherFx.__index = WeatherFx

local PRESETS = {
	Clear = { rate = 0, density = 0, haze = 0, dim = 0 },
	Rain = { rate = 700, speed = NumberRange.new(70, 90), life = NumberRange.new(0.6, 0.8), size = 0.07, squash = 8, color = Color3.fromRGB(170, 190, 210), density = 0.32, haze = 1.2, dim = 0.15 },
	Snow = { rate = 260, speed = NumberRange.new(5, 9), life = NumberRange.new(5, 7), size = 0.28, squash = 0, color = Color3.fromRGB(255, 255, 255), density = 0.3, haze = 1, dim = 0.05, spread = 35 },
	Fog = { rate = 0, density = 0.62, haze = 2.6, dim = 0.1 },
	Storm = { rate = 1400, speed = NumberRange.new(90, 110), life = NumberRange.new(0.5, 0.7), size = 0.08, squash = 10, color = Color3.fromRGB(160, 175, 200), density = 0.45, haze = 1.8, dim = 0.3, lightning = true },
}

function WeatherFx.new()
	local self = setmetatable({}, WeatherFx)
	self.state = { weather = "Clear", at = 0, auto = false, minutes = 5 }
	self.current = nil
	local emitterPart = Instance.new("Part")
	emitterPart.Name = "WsWeather"
	emitterPart.Anchored = true
	emitterPart.CanCollide = false
	emitterPart.CanQuery = false
	emitterPart.CanTouch = false
	emitterPart.Transparency = 1
	emitterPart.Size = Vector3.new(90, 1, 90)
	emitterPart.Parent = workspace
	self.part = emitterPart
	local e = Instance.new("ParticleEmitter")
	e.EmissionDirection = Enum.NormalId.Bottom
	e.Rate = 0
	e.LightInfluence = 0.6
	e.Parent = emitterPart
	self.emitter = e
	self.atmosphere = Instance.new("Atmosphere")
	self.atmosphere.Density = 0
	self.atmosphere.Parent = Lighting
	self.flash = Instance.new("ColorCorrectionEffect")
	self.flash.Parent = Lighting
	self.nextFlash = 0
	self.conn = RunService.RenderStepped:Connect(function()
		self:update()
	end)
	return self
end

function WeatherFx:set(state)
	self.state = state
end

function WeatherFx:apply(name: string)
	local p = PRESETS[name] or PRESETS.Clear
	self.current = name
	self.preset = p
	local e = self.emitter
	if p.rate > 0 then
		e.Speed = p.speed
		e.Lifetime = p.life
		e.Size = NumberSequence.new(p.size)
		e.Squash = NumberSequence.new(p.squash)
		e.Color = ColorSequence.new(p.color)
		e.Transparency = NumberSequence.new(0.35)
		local spread = p.spread or 4
		e.SpreadAngle = Vector2.new(spread, spread)
	end
	self.atmosphere.Density = p.density
	self.atmosphere.Haze = p.haze
	self.atmosphere.Color = Color3.fromRGB(190, 195, 205)
	self.flash.Brightness = -p.dim
	self.flash.Saturation = -p.dim
end

function WeatherFx:update()
	local s = self.state
	local name = Format.weatherAt({ auto = s.auto, minutes = s.minutes }, s.weather, s.at, workspace:GetServerTimeNow())
	if name ~= self.current then
		self:apply(name)
	end
	local p = self.preset
	local cam = workspace.CurrentCamera
	if not cam or not p then
		return
	end
	local pos = cam.CFrame.Position
	self.part.CFrame = CFrame.new(pos + Vector3.new(0, 30, 0))
	-- под крышей осадков нет
	local covered = false
	if p.rate > 0 then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local char = game:GetService("Players").LocalPlayer.Character
		params.FilterDescendantsInstances = { self.part, char }
		covered = workspace:Raycast(pos, Vector3.new(0, 80, 0), params) ~= nil
	end
	self.emitter.Rate = if covered then 0 else p.rate
	-- молния в грозу
	if p.lightning then
		local now = os.clock()
		if now >= self.nextFlash then
			self.nextFlash = now + 6 + math.random() * 9
			self.flash.Brightness = 0.6
			task.delay(0.12, function()
				self.flash.Brightness = -p.dim
			end)
		end
	end
end

function WeatherFx:destroy()
	self.conn:Disconnect()
	self.part:Destroy()
	self.atmosphere:Destroy()
	self.flash:Destroy()
end

return WeatherFx
