--!nonstrict
-- Каменная статуя из аватара Roblox: настоящая внешность игрока, всё в камне,
-- поза «восхищения»: правая рука поднята вверх, левая ниже и отведена назад,
-- голова запрокинута, ноги в шаге. Углы позы можно подправить в POSE

local Players = game:GetService("Players")

local Statue = {}

local STONE = Color3.fromRGB(196, 194, 190)

-- углы в градусах для суставов R15 (X — вперёд/назад, Z — в сторону)
Statue.POSE = {
	admire = {
		RightShoulder = { 165, 0, -12 },
		LeftShoulder = { -35, 0, 25 },
		RightElbow = { 15, 0, 0 },
		LeftElbow = { 25, 0, 0 },
		Neck = { 28, 0, 0 },
		Waist = { 8, 0, 0 },
		RightHip = { 18, 0, 0 },
		LeftHip = { -16, 0, 0 },
		RightKnee = { -10, 0, 0 },
		LeftKnee = { -22, 0, 0 },
	},
	stand = {},
}
-- для старых аватаров R6
Statue.POSE_R6 = {
	admire = {
		["Right Shoulder"] = { 0, 0, 165 },
		["Left Shoulder"] = { 0, 0, -35 },
		["Neck"] = { -25, 0, 0 },
		["Right Hip"] = { 0, 0, 15 },
		["Left Hip"] = { 0, 0, 15 },
	},
	stand = {},
}

local nameCache: { [string]: number } = {}

local function userIdOf(username: string): number?
	if nameCache[username] then
		return nameCache[username]
	end
	local ok, id = pcall(function()
		return Players:GetUserIdFromNameAsync(username)
	end)
	if ok and type(id) == "number" then
		nameCache[username] = id
		return id
	end
	return nil
end

local function petrify(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Material = Enum.Material.Marble
			d.Color = STONE
			d.CastShadow = true
			if d:IsA("MeshPart") then
				pcall(function()
					(d :: any).TextureID = ""
				end)
			end
		elseif d:IsA("SpecialMesh") then
			d.TextureId = ""
			d.VertexColor = Vector3.new(0.77, 0.76, 0.75)
		elseif d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") or d:IsA("Decal") or d:IsA("Texture") then
			d:Destroy()
		elseif d:IsA("SurfaceAppearance") or d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") then
			d:Destroy()
		elseif d:IsA("BodyColors") then
			for _, prop in { "HeadColor3", "TorsoColor3", "LeftArmColor3", "RightArmColor3", "LeftLegColor3", "RightLegColor3" } do
				(d :: any)[prop] = STONE
			end
		end
	end
end

-- Строит статую и ставит её так, чтобы ступни стояли в точке feetCF
function Statue.spawn(username: string, pose: string, orb: boolean, feetCF: CFrame, parent: Instance): Model?
	local userId = userIdOf(username)
	if not userId then
		return nil
	end
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromUserId(userId)
	end)
	if not ok or not model then
		return nil
	end
	model.Name = "Statue_" .. username
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not root then
		model:Destroy()
		return nil
	end
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.BreakJointsOnDeath = false
	local animator = hum:FindFirstChildOfClass("Animator")
	if animator then
		animator:Destroy()
	end
	petrify(model)
	-- поза: поворачиваем C0 суставов, пока детали ещё держатся только на суставах
	local r15 = hum.RigType == Enum.HumanoidRigType.R15
	local angles = (if r15 then Statue.POSE else Statue.POSE_R6)[pose] or {}
	for _, j in model:GetDescendants() do
		if j:IsA("Motor6D") and angles[j.Name] then
			local a = angles[j.Name]
			j.C0 = j.C0 * CFrame.Angles(math.rad(a[1]), math.rad(a[2]), math.rad(a[3]))
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = d == root
			d.CanCollide = d == root
		end
	end
	local lift = if r15 then hum.HipHeight + root.Size.Y / 2 else 3
	model.Parent = parent
	model:PivotTo(feetCF * CFrame.new(0, lift, 0))
	-- то, на что смотрит статуя: каменная сфера в поднятой руке
	if orb then
		local hand = model:FindFirstChild(if r15 then "RightHand" else "Right Arm") :: BasePart?
		if hand then
			local ball = Instance.new("Part")
			ball.Name = "Orb"
			ball.Shape = Enum.PartType.Ball
			ball.Size = Vector3.new(1.3, 1.3, 1.3)
			ball.Material = Enum.Material.Marble
			ball.Color = STONE
			ball.CanCollide = false
			ball.Massless = true
			ball.CFrame = hand.CFrame * CFrame.new(0, -hand.Size.Y / 2 - 0.5, 0)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = hand
			weld.Part1 = ball
			weld.Parent = ball
			ball.Parent = model
		end
	end
	-- суставы успели расставить детали: закрепляем всё, чтобы статуя не падала
	task.delay(0.3, function()
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = true
			end
		end
	end)
	return model
end

return Statue
