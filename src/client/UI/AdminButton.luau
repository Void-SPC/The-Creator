--!nonstrict
-- Маленькая кнопка админ-панели рядом с меню Roblox (в свободной области верхней панели)
-- Кнопка видна только администраторам, но каждое действие проверяется на сервере

local GuiService = game:GetService("GuiService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Workshop"):WaitForChild("Shared")
local UiText = require(Shared.UiText)
local Remotes = require(Shared.Roblox.Remotes)
local Kit = require(script.Parent.Kit)

local L = UiText.L

local AdminButton = {}

function AdminButton.mount(playerGui: PlayerGui)
	local res = Remotes.fn("Request"):InvokeServer("AdminStatus")
	if not res or not res.admin then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "WsAdmin"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Parent = playerGui
	local button = Kit.button(gui, L.Admin, nil, { Size = UDim2.fromOffset(64, 32), TextSize = 13, BackgroundTransparency = 0.2 })
	local function place()
		-- TopbarInset — свободная часть верхней панели справа от кнопок Roblox
		local inset = GuiService.TopbarInset
		local h = inset.Height
		if h <= 0 then
			button.Position = UDim2.fromOffset(104, 4)
		else
			button.Position = UDim2.fromOffset(inset.Min.X + 6, inset.Min.Y + math.max(0, (h - 32) / 2))
		end
	end
	place()
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(place)

	local panel: Frame? = nil
	local function close()
		if panel then
			panel:Destroy()
			panel = nil
		end
	end
	local function open()
		close()
		local w = math.min(420, Kit.viewport().X - 24)
		local p = Kit.frame(gui, { Size = UDim2.fromOffset(w, 420), Position = UDim2.fromOffset(12, 64) })
		panel = p
		Kit.corner(p, 12)
		Kit.pad(p, 10)
		Kit.label(p, L.AdminTitle, { Font = Kit.FONT_BOLD, TextSize = 17, Size = UDim2.new(1, -50, 0, 28) })
		Kit.button(p, "✕", close, { Size = UDim2.fromOffset(40, 32), Position = UDim2.new(1, -40, 0, -2) })
		local list = Kit.scroll(p, { Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 1, -36 - Kit.TAP * 2 - 12) })
		Kit.list(list, 6)
		local r = Remotes.fn("Request"):InvokeServer("AdminAction", "ListSessions")
		if r and r.ok then
			for i, s in r.sessions do
				local title = (s.code or L.SessionTest) .. "\n" .. string.format(L.PlayersCount, #s.players)
				Kit.button(list, title .. "\n" .. L.AdminEndSession, function()
					Remotes.fn("Request"):InvokeServer("AdminAction", "EndSession", s.id)
					open()
				end, { LayoutOrder = i * 10, Size = UDim2.new(1, -8, 0, 64) })
				for j, pl in s.players do
					Kit.button(list, pl.name .. "\n" .. L.AdminKick, function()
						Remotes.fn("Request"):InvokeServer("AdminAction", "Kick", pl.userId)
						open()
					end, { LayoutOrder = i * 10 + j, Size = UDim2.new(1, -24, 0, 52), TextSize = 13 })
				end
			end
		end
		local code = Kit.textbox(p, "", L.CodePlaceholder, nil, { Position = UDim2.new(0, 0, 1, -Kit.TAP * 2 - 6) })
		Kit.button(p, L.AdminUnlist, function()
			Remotes.fn("Request"):InvokeServer("AdminAction", "Unlist", code.Text)
			code.Text = ""
		end, { Position = UDim2.new(0, 0, 1, -Kit.TAP), BackgroundColor3 = Kit.C.bad })
	end
	button.Activated:Connect(function()
		if panel then
			close()
		else
			open()
		end
	end)
end

return AdminButton
