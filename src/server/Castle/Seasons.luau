--!nonstrict
-- Времена года и праздники замка: деревья (зимой без листьев), цвет травы, снег,
-- украшения. Меняется командой админа, всё старое убирается перед новым

local Lighting = game:GetService("Lighting")

local Seasons = {}

local terrain = workspace.Terrain
local folder: Folder?

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local LOOK = {
	summer = { grass = rgb(88, 140, 60), leaves = { rgb(70, 125, 50), rgb(90, 140, 60) }, tint = rgb(255, 240, 222) },
	spring = { grass = rgb(110, 165, 80), leaves = { rgb(120, 175, 90), rgb(240, 190, 210) }, tint = rgb(255, 244, 236), flowers = true },
	april = { grass = rgb(110, 165, 80), leaves = { rgb(120, 175, 90), rgb(255, 120, 200), rgb(120, 200, 255) }, tint = rgb(255, 236, 246), flowers = true, balloons = true },
	autumn = { grass = rgb(140, 130, 70), leaves = { rgb(200, 110, 40), rgb(220, 160, 50), rgb(160, 60, 30) }, tint = rgb(255, 228, 200), fallen = true },
	halloween = { grass = rgb(95, 100, 60), leaves = { rgb(150, 70, 30), rgb(90, 60, 40) }, tint = rgb(235, 210, 255), pumpkins = true, spooky = true },
	winter = { grass = rgb(235, 240, 245), leaves = nil, tint = rgb(225, 235, 255), snow = true },
	newyear = { grass = rgb(235, 240, 245), leaves = nil, tint = rgb(225, 235, 255), snow = true, tree = true },
}
Seasons.LIST = { "summer", "spring", "april", "autumn", "halloween", "winter", "newyear" }

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = props.Parent or folder
	return p
end

local function tree(pos: Vector3, look, rnd: Random)
	local h = rnd:NextNumber(10, 15)
	part({ Name = "Trunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 1.6, 1.6), CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(90, 64, 44), Material = Enum.Material.Wood })
	if look.leaves then
		for i = 1, 4 do
			local d = rnd:NextNumber(5, 8)
			local off = Vector3.new(rnd:NextNumber(-2.5, 2.5), h + rnd:NextNumber(-1, 2.5), rnd:NextNumber(-2.5, 2.5))
			local c = look.leaves[rnd:NextInteger(1, #look.leaves)]
			part({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.new(d, d, d), CFrame = CFrame.new(pos + off), Color = c, Material = Enum.Material.LeafyGrass, CanCollide = i == 1, CastShadow = true })
		end
	else
		-- голые ветки
		for i = 1, 5 do
			local a = i / 5 * math.pi * 2
			local len = rnd:NextNumber(3, 5)
			part({ Name = "Branch", Size = Vector3.new(0.5, len, 0.5), CFrame = CFrame.new(pos + Vector3.new(0, h - 1, 0)) * CFrame.Angles(0, a, math.rad(35)) * CFrame.new(0, len / 2, 0), Color = rgb(80, 58, 40), Material = Enum.Material.Wood, CanCollide = false })
		end
		if look.snow then
			part({ Name = "SnowCap", Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 1.2, 2.4), CFrame = CFrame.new(pos + Vector3.new(0, h + 0.2, 0)), Color = rgb(250, 252, 255), Material = Enum.Material.Snow, CanCollide = false })
		end
	end
	if look.fallen then
		for _ = 1, 6 do
			local c = look.leaves[rnd:NextInteger(1, #look.leaves)]
			part({ Name = "FallenLeaf", Size = Vector3.new(0.8, 0.05, 0.6), CFrame = CFrame.new(pos + Vector3.new(rnd:NextNumber(-5, 5), 0.05, rnd:NextNumber(-5, 5))) * CFrame.Angles(0, rnd:NextNumber(0, 6.28), 0), Color = c, Material = Enum.Material.Fabric, CanCollide = false })
		end
	end
	if look.flowers then
		for _ = 1, 5 do
			local c = Color3.fromHSV(rnd:NextNumber(), 0.6, 1)
			part({ Name = "Flower", Shape = Enum.PartType.Ball, Size = Vector3.new(0.6, 0.6, 0.6), CFrame = CFrame.new(pos + Vector3.new(rnd:NextNumber(-4, 4), 0.4, rnd:NextNumber(-4, 4))), Color = c, Material = Enum.Material.SmoothPlastic, CanCollide = false })
		end
	end
end

local function pumpkin(pos: Vector3, glow: boolean)
	local p = part({ Name = "Pumpkin", Shape = Enum.PartType.Ball, Size = Vector3.new(2.6, 2, 2.6), CFrame = CFrame.new(pos + Vector3.new(0, 1, 0)), Color = rgb(230, 120, 30), Material = Enum.Material.SmoothPlastic })
	part({ Name = "Stem", Size = Vector3.new(0.3, 0.7, 0.3), CFrame = CFrame.new(pos + Vector3.new(0, 2.2, 0)), Color = rgb(70, 90, 40), Material = Enum.Material.Wood, CanCollide = false })
	if glow then
		local l = Instance.new("PointLight")
		l.Color = rgb(255, 140, 40)
		l.Range = 10
		l.Brightness = 1.5
		l.Parent = p
	end
end

local function newYearTree(pos: Vector3)
	part({ Name = "Trunk", Size = Vector3.new(2, 4, 2), CFrame = CFrame.new(pos + Vector3.new(0, 2, 0)), Color = rgb(90, 64, 44), Material = Enum.Material.Wood })
	for k = 0, 5 do
		local r = 16 - k * 2.5
		part({ Name = "Fir", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, r, r), CFrame = CFrame.new(pos + Vector3.new(0, 5 + k * 3, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(30, 90, 50), Material = Enum.Material.LeafyGrass })
		for j = 0, 7 - k do
			local a = j / (8 - k) * math.pi * 2 + k
			local b = part({ Name = "Ornament", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.9, 0.9), CFrame = CFrame.new(pos + Vector3.new(math.cos(a) * r / 2, 4.2 + k * 3, math.sin(a) * r / 2)), Color = Color3.fromHSV((j * 0.13 + k * 0.2) % 1, 0.8, 1), Material = Enum.Material.Neon, CanCollide = false })
			local _ = b
		end
	end
	local star = part({ Name = "Star", Shape = Enum.PartType.Ball, Size = Vector3.new(2.2, 2.2, 2.2), CFrame = CFrame.new(pos + Vector3.new(0, 23.5, 0)), Color = rgb(255, 220, 90), Material = Enum.Material.Neon, CanCollide = false })
	local l = Instance.new("PointLight")
	l.Color = rgb(255, 220, 140)
	l.Range = 30
	l.Brightness = 2
	l.Parent = star
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		part({ Name = "Gift", Size = Vector3.new(2, 1.6, 2), CFrame = CFrame.new(pos + Vector3.new(math.cos(a) * 9, 0.8, math.sin(a) * 9)) * CFrame.Angles(0, a, 0), Color = Color3.fromHSV(k / 6, 0.7, 0.9), Material = Enum.Material.SmoothPlastic })
	end
end

local function balloon(pos: Vector3, c: Color3)
	part({ Name = "Balloon", Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2.4, 2), CFrame = CFrame.new(pos), Color = c, Material = Enum.Material.SmoothPlastic, CanCollide = false })
	part({ Name = "String", Size = Vector3.new(0.05, 6, 0.05), CFrame = CFrame.new(pos - Vector3.new(0, 4, 0)), Color = rgb(240, 240, 240), CanCollide = false })
end

-- trees — точки деревьев из постройки, roofs — крыши (зимой их присыпает снегом)
function Seasons.apply(season: string, trees: { Vector3 })
	local look = LOOK[season] or LOOK.summer
	if folder then
		folder:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = "Season"
	folder = f
	local rnd = Random.new(7)
	for _, pos in trees do
		tree(pos, look, rnd)
	end
	pcall(function()
		terrain:SetMaterialColor(Enum.Material.Grass, look.grass)
		terrain:SetMaterialColor(Enum.Material.Mud, if look.snow then rgb(220, 225, 232) else rgb(90, 70, 50))
		terrain:SetMaterialColor(Enum.Material.Cobblestone, if look.snow then rgb(200, 205, 212) else rgb(130, 126, 120))
	end)
	if look.snow then
		-- снежные шапки на зубцах и сугробы во дворе
		for i = 1, 30 do
			part({ Name = "Snowdrift", Shape = Enum.PartType.Ball, Size = Vector3.new(rnd:NextNumber(4, 8), 1.2, rnd:NextNumber(4, 8)), CFrame = CFrame.new(rnd:NextNumber(-160, 160), 0.1, rnd:NextNumber(-168, -120)), Color = rgb(250, 252, 255), Material = Enum.Material.Snow, CanCollide = false })
			local _ = i
		end
	end
	if look.pumpkins then
		for i = 0, 15 do
			local x = if i % 2 == 0 then -30 else 30
			pumpkin(Vector3.new(x, 0, -168 + i * 3), true)
		end
		for _, pos in trees do
			pumpkin(pos + Vector3.new(3, 0, 2), false)
		end
		-- паутина в углах двора и летучие мыши
		for k = 0, 7 do
			local bat = part({ Name = "Bat", Size = Vector3.new(2, 0.2, 0.8), CFrame = CFrame.new(math.cos(k) * 60, 60 + k * 3, -140 + math.sin(k) * 40), Color = rgb(20, 18, 22), Material = Enum.Material.SmoothPlastic, CanCollide = false })
			local _ = bat
		end
	end
	if look.tree then
		newYearTree(Vector3.new(110, 0, -140))
		for z = -160, 160, 16 do
			for _, x in { -169, 169 } do
				local p = part({ Name = "Garland", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.8, 0.8), CFrame = CFrame.new(x, 20, z), Color = Color3.fromHSV(((z + 160) / 320) % 1, 0.8, 1), Material = Enum.Material.Neon, CanCollide = false })
				local _ = p
			end
		end
	end
	if look.balloons then
		for k = 0, 19 do
			balloon(Vector3.new(math.cos(k) * 50, 16 + (k % 4) * 3, -142 + math.sin(k * 1.7) * 22), Color3.fromHSV(k / 20, 0.7, 1))
		end
	end
	f.Parent = workspace
	local cc = Lighting:FindFirstChild("CastleColor")
	if cc then
		(cc :: ColorCorrectionEffect).TintColor = look.tint
	end
	return look
end

-- погода по умолчанию для времени года
function Seasons.defaultWeather(season: string): string
	if season == "winter" or season == "newyear" then
		return "Snow"
	elseif season == "autumn" then
		return "Rain"
	elseif season == "halloween" then
		return "Fog"
	end
	return "Clear"
end

return Seasons
