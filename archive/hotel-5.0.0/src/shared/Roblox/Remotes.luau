--!nonstrict
-- Сетевые каналы игры. Сервер создаёт их, клиент ждёт появления

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local FUNCTIONS = { "Request", "AdminRequest" }
local EVENTS = { "Game" }

local folder: Folder

local function root(): Folder
	if folder then
		return folder
	end
	local ws = ReplicatedStorage:WaitForChild("Workshop")
	if RunService:IsServer() then
		local f = ws:FindFirstChild("Remotes") :: Folder?
		if not f then
			local nf = Instance.new("Folder")
			nf.Name = "Remotes"
			for _, name in FUNCTIONS do
				local rf = Instance.new("RemoteFunction")
				rf.Name = name
				rf.Parent = nf
			end
			for _, name in EVENTS do
				local re = Instance.new("RemoteEvent")
				re.Name = name
				re.Parent = nf
			end
			nf.Parent = ws
			f = nf
		end
		folder = f :: Folder
	else
		folder = ws:WaitForChild("Remotes") :: Folder
	end
	return folder
end

function Remotes.fn(name: string): RemoteFunction
	return root():WaitForChild(name) :: RemoteFunction
end

function Remotes.event(name: string): RemoteEvent
	return root():WaitForChild(name) :: RemoteEvent
end

return Remotes
