--!nonstrict
-- Одежда ролей и украшения из магазина. Всё — простые детали, приваренные к персонажу,
-- поэтому работает с любым аватаром (R15 и R6) и не требует загрузки ассетов

local MAT = require(game:GetService("ReplicatedStorage").Workshop.Shared.Materials)
local Npc = require(script.Parent.Npc)

local Outfits = {}

local weld = Npc.weldPart

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local GOLD = rgb(214, 172, 80)
local STEEL = rgb(170, 172, 180)

local function partOf(char: Model, ...): BasePart?
	for _, n in { ... } do
		local p = char:FindFirstChild(n)
		if p and p:IsA("BasePart") then
			return p
		end
	end
	return nil
end

local function headTop(head: BasePart, h: number): CFrame
	return CFrame.new(0, head.Size.Y / 2 + h / 2 - 0.05, 0)
end

local function crown(f, head, big)
	local s = if big then 1 else 0.8
	weld(f, head, { Name = "CrownBand", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.45 * s, 1.25 * s, 1.25 * s), Color = GOLD, Material = MAT.Metal }, headTop(head, 0.45) * CFrame.Angles(0, 0, math.pi / 2))
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2
		weld(f, head, { Name = "CrownSpike", Size = Vector3.new(0.18, 0.45 * s, 0.18), Color = GOLD, Material = MAT.Metal }, headTop(head, 0.45) * CFrame.new(math.cos(a) * 0.55 * s, 0.4 * s, math.sin(a) * 0.55 * s))
		weld(f, head, { Name = "Gem", Shape = Enum.PartType.Ball, Size = Vector3.new(0.16, 0.16, 0.16), Color = if k % 2 == 0 then rgb(200, 30, 50) else rgb(40, 90, 220), Material = MAT.Neon }, headTop(head, 0.45) * CFrame.new(math.cos(a) * 0.63 * s, 0, math.sin(a) * 0.63 * s))
	end
end

local function cape(f, torso, color)
	weld(f, torso, { Name = "Cape", Size = Vector3.new(1.9, 3.6, 0.12), Color = color, Material = MAT.SmoothPlastic }, CFrame.new(0, -0.9, 0.62) * CFrame.Angles(math.rad(6), 0, 0))
	weld(f, torso, { Name = "CapeCollar", Size = Vector3.new(2.1, 0.3, 1.2), Color = rgb(240, 236, 228), Material = MAT.SmoothPlastic }, CFrame.new(0, torso.Size.Y / 2, 0))
end

-- Королевская мантия: длинная, гладкая, с горностаевым воротником и золотой застёжкой
local function mantle(f, torso, color)
	weld(f, torso, { Name = "Mantle", Size = Vector3.new(2.3, 4.6, 0.14), Color = color, Material = MAT.SmoothPlastic, Reflectance = 0.05 }, CFrame.new(0, -1.5, 0.66) * CFrame.Angles(math.rad(7), 0, 0))
	weld(f, torso, { Name = "MantleLining", Size = Vector3.new(2.2, 4.5, 0.05), Color = GOLD:Lerp(color, 0.3), Material = MAT.SmoothPlastic }, CFrame.new(0, -1.45, 0.58) * CFrame.Angles(math.rad(7), 0, 0))
	weld(f, torso, { Name = "Ermine", Size = Vector3.new(2.4, 0.5, 1.4), Color = rgb(246, 244, 238), Material = MAT.SmoothPlastic }, CFrame.new(0, torso.Size.Y / 2 + 0.05, 0.05))
	for k = 0, 5 do
		weld(f, torso, { Name = "ErmineSpot", Size = Vector3.new(0.12, 0.22, 0.05), Color = rgb(20, 20, 20), Material = MAT.SmoothPlastic }, CFrame.new(-0.9 + k * 0.36, torso.Size.Y / 2 + 0.05, -0.68))
	end
	weld(f, torso, { Name = "Clasp", Shape = Enum.PartType.Ball, Size = Vector3.new(0.4, 0.4, 0.4), Color = GOLD, Material = MAT.Metal }, CFrame.new(0, torso.Size.Y / 2 - 0.2, -torso.Size.Z / 2 - 0.15))
end

-- Причёска и шляпы аватара под короной скрыты, чтобы корона была видна всем
function Outfits.setHeadwearHidden(char: Model, hidden: boolean)
	local head = char:FindFirstChild("Head")
	for _, acc in char:GetChildren() do
		if acc:IsA("Accessory") then
			local h = acc:FindFirstChild("Handle")
			if h and h:IsA("BasePart") then
				local onHead = false
				for _, a in h:GetChildren() do
					if a:IsA("Attachment") and (string.find(a.Name, "Hat") or string.find(a.Name, "Hair") or string.find(a.Name, "FaceFront") or string.find(a.Name, "FaceCenter")) then
						onHead = true
					end
				end
				local w = h:FindFirstChild("AccessoryWeld")
				if w and ((w :: any).Part1 == head or (w :: any).Part0 == head) then
					onHead = true
				end
				if onHead then
					if hidden then
						if h:GetAttribute("OrigT") == nil then
							h:SetAttribute("OrigT", h.Transparency)
						end
						h.Transparency = 1
					elseif h:GetAttribute("OrigT") ~= nil then
						h.Transparency = h:GetAttribute("OrigT")
						h:SetAttribute("OrigT", nil)
					end
				end
			end
		end
	end
end

local function front(f, torso, color, h)
	weld(f, torso, { Name = "Front", Size = Vector3.new(torso.Size.X * 0.85, h or torso.Size.Y * 0.95, 0.1), Color = color, Material = MAT.SmoothPlastic }, CFrame.new(0, -0.1, -torso.Size.Z / 2 - 0.05))
end

local function hat(f, head, color, r, h, mat)
	weld(f, head, { Name = "Hat", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, r, r), Color = color, Material = mat or MAT.SmoothPlastic }, headTop(head, h) * CFrame.Angles(0, 0, math.pi / 2))
end

-- role: одежда роли; worn: { [id] = true } — украшения из магазина
function Outfits.apply(char: Model, role: string?, worn: { [string]: boolean }?)
	local old = char:FindFirstChild("CastleOutfit")
	if old then
		old:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = "CastleOutfit"
	f.Parent = char
	local head = partOf(char, "Head")
	local torso = partOf(char, "UpperTorso", "Torso")
	if not head or not torso then
		return
	end
	Outfits.setHeadwearHidden(char, role == "king" or role == "queen")
	if role == "king" then
		crown(f, head, true)
		mantle(f, torso, rgb(150, 20, 30))
	elseif role == "queen" then
		crown(f, head, false)
		mantle(f, torso, rgb(110, 40, 140))
	elseif role == "commander" then
		weld(f, head, { Name = "Helmet", Size = Vector3.new(head.Size.X * 1.1, 0.8, head.Size.Z * 1.1), Color = STEEL, Material = MAT.Metal }, headTop(head, 0.8) * CFrame.new(0, -0.35, 0))
		weld(f, head, { Name = "Plume", Size = Vector3.new(0.2, 0.9, 1.2), Color = rgb(170, 20, 30), Material = MAT.SmoothPlastic }, headTop(head, 0.9) * CFrame.new(0, 0.35, 0.1))
		cape(f, torso, rgb(30, 40, 80))
		front(f, torso, rgb(150, 20, 30))
	elseif role == "guard" then
		weld(f, head, { Name = "Helmet", Size = Vector3.new(head.Size.X * 1.1, 0.8, head.Size.Z * 1.1), Color = STEEL, Material = MAT.Metal }, headTop(head, 0.8) * CFrame.new(0, -0.35, 0))
		front(f, torso, rgb(150, 20, 30))
		weld(f, torso, { Name = "Emblem", Size = Vector3.new(0.6, 0.6, 0.05), Color = GOLD, Material = MAT.Metal }, CFrame.new(0, 0.2, -torso.Size.Z / 2 - 0.12))
	elseif role == "cook" then
		hat(f, head, rgb(250, 250, 250), 1.3, 1.2)
		front(f, torso, rgb(245, 245, 240))
	elseif role == "servant" then
		hat(f, head, rgb(80, 80, 90), 1.25, 0.35)
		front(f, torso, rgb(230, 225, 215), torso.Size.Y * 0.7)
	elseif role == "librarian" then
		weld(f, head, { Name = "Hood", Shape = Enum.PartType.Ball, Size = head.Size * 1.25, Color = rgb(70, 50, 90), Material = MAT.SmoothPlastic }, CFrame.new(0, 0.1, 0.12))
		front(f, torso, rgb(70, 50, 90))
	elseif role == "peasant" then
		hat(f, head, rgb(214, 186, 110), 2.4, 0.2, MAT.Grass)
		hat(f, head, rgb(214, 186, 110), 1.2, 0.5, MAT.Grass)
	end
	worn = worn or {}
	if worn.flower_crown and role ~= "king" and role ~= "queen" then
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2
			weld(f, head, { Name = "Flower", Shape = Enum.PartType.Ball, Size = Vector3.new(0.3, 0.3, 0.3), Color = Color3.fromHSV(k / 8, 0.5, 1), Material = MAT.SmoothPlastic }, headTop(head, 0.3) * CFrame.new(math.cos(a) * 0.62, -0.1, math.sin(a) * 0.62))
		end
	end
	if worn.cape_red and role ~= "king" then
		cape(f, torso, rgb(170, 30, 40))
	elseif worn.cape_blue and role ~= "king" then
		cape(f, torso, rgb(40, 70, 160))
	end
	if worn.halo then
		weld(f, head, { Name = "Halo", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 1.5, 1.5), Color = rgb(255, 230, 140), Material = MAT.Neon, Transparency = 0.15 }, headTop(head, 0.1) * CFrame.new(0, 0.9, 0) * CFrame.Angles(0, 0, math.pi / 2))
	end
	if worn.glasses then
		for _, s in { -1, 1 } do
			weld(f, head, { Name = "Lens", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.06, 0.4, 0.4), Color = rgb(30, 30, 34), Material = MAT.Glass, Transparency = 0.2 }, CFrame.new(s * 0.25, 0.15, -head.Size.Z / 2 - 0.03) * CFrame.Angles(0, math.pi / 2, 0))
		end
		weld(f, head, { Name = "Bridge", Size = Vector3.new(0.12, 0.05, 0.05), Color = rgb(30, 30, 34), Material = MAT.Metal }, CFrame.new(0, 0.2, -head.Size.Z / 2 - 0.03))
	end
	if worn.feather_hat and role ~= "king" and role ~= "queen" and role ~= "guard" and role ~= "commander" then
		hat(f, head, rgb(60, 40, 90), 1.9, 0.6)
		weld(f, head, { Name = "Feather", Size = Vector3.new(0.12, 1.5, 0.4), Color = rgb(240, 240, 255), Material = MAT.SmoothPlastic }, headTop(head, 0.6) * CFrame.new(0.5, 0.7, 0.2) * CFrame.Angles(0, 0, math.rad(-25)))
	end
	if worn.backpack then
		weld(f, torso, { Name = "Backpack", Size = Vector3.new(1.4, 1.6, 0.8), Color = rgb(120, 85, 50), Material = MAT.Leather }, CFrame.new(0, 0, torso.Size.Z / 2 + 0.45))
	end
	if worn.wings then
		for _, s in { -1, 1 } do
			weld(f, torso, { Name = "Wing", Size = Vector3.new(2.6, 3, 0.1), Color = rgb(250, 250, 255), Material = MAT.SmoothPlastic, Transparency = 0.1 }, CFrame.new(s * 1.4, 0.5, torso.Size.Z / 2 + 0.3) * CFrame.Angles(0, s * math.rad(30), s * math.rad(-15)))
		end
	end
end

return Outfits
